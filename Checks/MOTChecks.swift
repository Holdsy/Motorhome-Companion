import Foundation

@main struct MOTChecks {
    static func main() throws {
        let details = MOTDetails(text: "MOT test certificate\nRegistration number\nAB12 CDE\nDate of the test\n01.04.2026\nExpiry date\n31.03.2027\nOdometer reading\n14,768 miles\nMOT test number: 1234 5678 9012\nTest result: PASSED")
        precondition(details.registration == "AB12 CDE")
        precondition(details.certificate == "1234 5678 9012")
        precondition(details.result == "PASSED")
        precondition(details.mileage == "14768")
        precondition(Calendar.current.component(.year, from: details.expiryDate!) == 2027)
        precondition(Calendar.current.component(.month, from: details.testDate!) == 4)
        let missing = MOTDetails(text: "Date of test: 1 April 2026\nOdometer reading: 24,000 km")
        precondition(missing.testDate != nil && missing.expiryDate == nil && missing.mileage == nil)
        precondition(MOTDetails(text: "Expiry date: 31/02/2027").expiryDate == nil)
        let printed = MOTDetails(text: "⑦ Pass\n⑨ Testing organisation and inspector name\nS002697 TAYLOR'S AUTOS\nK. Jones")
        precondition(printed.result == "Pass")
        precondition(printed.provider == "TAYLOR'S AUTOS")
        precondition(MOTDetails(text: "Please pass this document to the owner").result.isEmpty)
        precondition(MOTDetails(text: "7 Fail").result == "Fail")
        if CommandLine.arguments.count > 1 {
            let scan = MOTDetails(text: try String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8))
            precondition(scan.result == "Pass" && scan.provider == "TAYLOR'S AUTOS")
            precondition(scan.registration == "FX19AGY" && scan.mileage == "14768")
            precondition(scan.certificate == "6626 0032 4643")
            precondition(Calendar.current.component(.day, from: scan.expiryDate!) == 8)
            precondition(Calendar.current.component(.month, from: scan.expiryDate!) == 4)
            precondition(Calendar.current.component(.year, from: scan.expiryDate!) == 2027)
        }
        print("PASS: MOT fields, printed dates, missing expiry, invalid dates and kilometre readings")
    }
}
