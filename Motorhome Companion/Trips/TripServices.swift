import Foundation
import MapKit
import Observation
import UniformTypeIdentifiers

struct PlaceResult: Identifiable {
    let id = UUID()
    let mapItem: MKMapItem
    var name: String { mapItem.name ?? "Unnamed place" }
    var coordinate: CLLocationCoordinate2D { mapItem.placemark.coordinate }
    var address: String { mapItem.placemark.title ?? "" }
}

@MainActor @Observable
final class PlaceSearchService {
    var results: [PlaceResult] = []
    var isSearching = false
    var errorMessage: String?
    private var currentSearch: MKLocalSearch?

    func search(query: String, region: MKCoordinateRegion?) async {
        currentSearch?.cancel()
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { results = []; return }
        isSearching = true
        errorMessage = nil
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = term
        if let region { request.region = region }
        let search = MKLocalSearch(request: request)
        currentSearch = search
        defer { if currentSearch === search { currentSearch = nil; isSearching = false } }
        do {
            results = try await search.start().mapItems.map(PlaceResult.init)
        } catch is CancellationError {
        } catch {
            results = []
            errorMessage = "Search is unavailable. Check your connection and try again."
        }
    }

    func cancel() { currentSearch?.cancel() }
}

struct RouteLeg: Identifiable {
    let id: String
    let from: TripStop
    let to: TripStop
    let route: MKRoute?
    let errorDescription: String?
    var distanceMetres: Double { route?.distance ?? 0 }
    var drivingSeconds: TimeInterval { route?.expectedTravelTime ?? 0 }
}

@MainActor @Observable
final class TripRouteService {
    var legs: [RouteLeg] = []
    var isCalculating = false

    func calculate(stops: [TripStop]) async {
        legs = []
        let pairs = zip(stops, stops.dropFirst()).filter { $0.category != .transport && $1.category != .transport }
        guard !pairs.isEmpty else { return }
        isCalculating = true
        defer { isCalculating = false }
        for (from, to) in pairs {
            guard !Task.isCancelled else { return }
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: .init(latitude: from.latitude, longitude: from.longitude)))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: .init(latitude: to.latitude, longitude: to.longitude)))
            request.transportType = .automobile
            do {
                let response = try await MKDirections(request: request).calculate()
                legs.append(RouteLeg(id: "\(from.persistentModelID)-\(to.persistentModelID)", from: from, to: to, route: response.routes.first, errorDescription: nil))
            } catch {
                legs.append(RouteLeg(id: "\(from.persistentModelID)-\(to.persistentModelID)", from: from, to: to, route: nil, errorDescription: "Route unavailable"))
            }
        }
    }
}

enum TripMath {
    static let metresPerMile = 1_609.344
    static let imperialGallonsToLitres = 4.54609

    static func miles(fromMetres metres: Double) -> Double { metres / metresPerMile }
    static func kilometres(fromMetres metres: Double) -> Double { metres / 1_000 }
    static func litresPer100KM(fromImperialMPG mpg: Double) -> Double { 282.481 / mpg }
    static func fuelLitres(distanceMiles: Double, imperialMPG: Double) -> Double { distanceMiles / imperialMPG * imperialGallonsToLitres }
    static func fuelCost(distanceMiles: Double, imperialMPG: Double, pricePerLitre: Double) -> Double {
        fuelLitres(distanceMiles: distanceMiles, imperialMPG: imperialMPG) * pricePerLitre
    }
}

enum TripCalendar {
    static func localDay(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
    }

    static func dates(from start: Date, through end: Date, calendar: Calendar = .current) -> [Date] {
        var dates: [Date] = []
        var date = localDay(start, calendar: calendar)
        let final = localDay(end, calendar: calendar)
        while date <= final {
            dates.append(date)
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        return dates
    }
}

enum TripExport {
    static func orderedStops(for trip: Trip, day: TripDay? = nil) -> [TripStop] {
        if let day { return day.orderedStops }
        return trip.itineraryDays.flatMap(\.orderedStops)
    }

    static func gpx(trip: Trip, day: TripDay? = nil) -> String {
        let stops = orderedStops(for: trip, day: day)
        let waypoints = stops.map { "<wpt lat=\"\($0.latitude)\" lon=\"\($0.longitude)\"><name>\(xml($0.name))</name></wpt>" }.joined()
        let points = stops.map { "<rtept lat=\"\($0.latitude)\" lon=\"\($0.longitude)\"><name>\(xml($0.name))</name></rtept>" }.joined()
        return "<?xml version=\"1.0\" encoding=\"UTF-8\"?><gpx version=\"1.1\" creator=\"Motorhome Companion\" xmlns=\"http://www.topografix.com/GPX/1/1\">\(waypoints)<rte><name>\(xml(trip.name))</name>\(points)</rte></gpx>"
    }

    static func csv(trip: Trip, day: TripDay? = nil) -> String {
        let rows = orderedStops(for: trip, day: day).enumerated().map { index, stop in
            "\(index + 1),\(csvField(stop.name)),\(stop.latitude),\(stop.longitude),\(csvField(stop.address)),\(csvField(stop.category.title))"
        }
        return (["Order,Name,Latitude,Longitude,Address,Category"] + rows).joined(separator: "\n")
    }

    static func itinerary(trip: Trip) -> String {
        var lines = [trip.name, "\(trip.start.ukDate) – \(trip.end.ukDate)", "General car estimates only; check routes on your Garmin."]
        for day in trip.itineraryDays {
            lines.append("\n\(day.date.ukDate)")
            for (index, stop) in day.orderedStops.enumerated() { lines.append("\(index + 1). \(stop.name) — \(stop.category.title)") }
        }
        return lines.joined(separator: "\n")
    }

    private static func xml(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }
    private static func csvField(_ value: String) -> String { "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
}

struct TripExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.xml, .commaSeparatedText, .plainText] }
    let text: String
    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws { text = String(data: configuration.file.regularFileContents ?? Data(), encoding: .utf8) ?? "" }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: Data(text.utf8)) }
}
