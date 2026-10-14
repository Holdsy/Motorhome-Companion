import Foundation

struct MOTDetails: Sendable {
    var testDate: Date?
    var expiryDate: Date?
    var mileage: String?
    var registration: String = ""
    var certificate: String = ""
    var result: String = ""
    var provider: String = ""
    var text: String

    init(text: String) {
        self.text = text
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        func value(_ labels: [String]) -> String? {
            for (index, line) in lines.enumerated() {
                for label in labels {
                    guard let range = line.range(of: label, options: .caseInsensitive) else { continue }
                    let suffix = String(line[range.upperBound...]).trimmingCharacters(in: CharacterSet(charactersIn: " :–-"))
                    if !suffix.isEmpty { return suffix }
                    if index + 1 < lines.count { return lines[index + 1] }
                }
            }
            return nil
        }
        func date(_ value: String?) -> Date? {
            guard let value else { return nil }
            let pattern = #"\b(?:\d{1,2}[/.\-]\d{1,2}[/.\-]\d{4}|\d{1,2}\s+[A-Za-z]+\s+\d{4})\b"#
            guard let range = value.range(of: pattern, options: .regularExpression) else { return nil }
            let candidate = String(value[range])
            for format in ["dd.MM.yyyy", "dd/MM/yyyy", "dd-MM-yyyy", "d MMMM yyyy", "d MMM yyyy"] {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_GB")
                formatter.dateFormat = format
                formatter.isLenient = false
                if let parsed = formatter.date(from: candidate) { return parsed }
            }
            return nil
        }
        testDate = date(value(["Date of the test", "Date of test", "Test date"]))
        expiryDate = date(value(["Expiry date", "Date of expiry", "Valid until"]))
        registration = value(["Registration number", "Registration mark", "Vehicle registration"]) ?? ""
        certificate = value(["MOT test number", "Test number", "Certificate number"]) ?? ""
        result = value(["Test result"]) ?? ""
        // Printed certificates use a standalone outcome, often preceded by field number 7.
        if result.isEmpty {
            for line in lines {
                let outcome = line.replacingOccurrences(of: #"^[\s•·⑦(7).:]+"#, with: "", options: .regularExpression)
                if ["pass", "passed", "fail", "failed"].contains(outcome.lowercased()) {
                    result = outcome
                    break
                }
            }
        }
        if let organisation = value(["Testing organisation and inspector name", "Testing organization and inspector name", "Testing organisation", "Testing organization", "Test centre name", "Test center name"]) {
            // Keep the business name, excluding the station identifier and next-line inspector.
            provider = organisation.replacingOccurrences(of: #"^[A-Za-z]?[0-9Oo]{4,}\s+"#, with: "", options: .regularExpression)
        }
        if let reading = value(["Odometer reading", "Mileage"]), reading.localizedCaseInsensitiveContains("mile"),
           let range = reading.range(of: #"\b\d[\d, ]*"#, options: .regularExpression) {
            let digits = reading[range].filter { $0.isNumber }
            if let number = Int(digits), number <= 9_999_999 { mileage = String(digits) }
        }
    }
}

