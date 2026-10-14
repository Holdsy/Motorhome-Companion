import Foundation

struct InsuranceDetails {
    var provider = ""
    var policy = ""
    var registration = ""
    var policyholder = ""
    var start: Date?
    var expiry: Date?
    init(text: String) {
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        func value(_ label: String) -> String {
            guard let index = lines.firstIndex(where: { $0.localizedCaseInsensitiveContains(label) }) else { return "" }
            let line = lines[index]
            let range = line.range(of: label, options: .caseInsensitive)!
            let suffix = line[range.upperBound...].trimmingCharacters(in: CharacterSet(charactersIn: " :"))
            return suffix.isEmpty && index + 1 < lines.count ? lines[index + 1] : suffix
        }
        func date(_ string: String) -> Date? {
            guard let range = string.range(of: #"\b\d{1,2}/\d{1,2}/\d{4}(?:\s+\d{2}:\d{2})?\b"#, options: .regularExpression) else { return nil }
            let candidate = String(string[range])
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_GB")
            formatter.dateFormat = candidate.contains(":") ? "dd/MM/yyyy HH:mm" : "dd/MM/yyyy"
            formatter.isLenient = false
            return formatter.date(from: candidate)
        }
        policy = value("Policy Number")
        if let index = lines.firstIndex(where: { $0.caseInsensitiveCompare("Policy Number") == .orderedSame }), index + 2 < lines.count,
           lines[index + 2].range(of: #"^[A-Z]+\s+\d+"#, options: .regularExpression) != nil {
            policy += " / " + lines[index + 2]
        }
        policyholder = value("Name of policyholder")
        let vehicle = value("Description of vehicle(s)")
        if let range = vehicle.range(of: #"\b[A-Z]{2}\d{2}\s?[A-Z]{3}\b"#, options: .regularExpression) { registration = String(vehicle[range]) }
        start = date(value("Effective date and time of the commencement of insurance for the purposes of the relevant law"))
        if start == nil { start = date(value("Start date")) }
        expiry = date(value("Date of expiry of insurance"))
        if expiry == nil { expiry = date(value("Expiry date")) }
        provider = value("Insurance provider")
        if provider.isEmpty, let line = lines.first(where: { $0.localizedCaseInsensitiveContains("Authorised Signatory,") }) {
            provider = line.components(separatedBy: ",").dropFirst().joined(separator: ",").trimmingCharacters(in: .whitespaces)
        }
    }
}
