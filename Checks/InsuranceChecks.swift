import Foundation
import PDFKit
@main struct InsuranceChecks {
 static func main() throws {
 let document = PDFDocument(url: URL(fileURLWithPath: CommandLine.arguments[1]))!
 let details = InsuranceDetails(text: document.string!)
 precondition(details.provider == "Ripe Insurance Services Ltd")
 precondition(details.policy == "RIPE CMH304939 / ERS 40683849")
 precondition(details.registration == "FX19AGY")
 precondition(details.policyholder == "Mr Mark Holdsworth")
 let calendar = Calendar.current
 precondition(calendar.component(.year, from: details.expiry!) == 2027)
 precondition(calendar.component(.month, from: details.expiry!) == 5)
 precondition(calendar.component(.day, from: details.expiry!) == 5)
 precondition(calendar.component(.hour, from: details.expiry!) == 23)
 precondition(calendar.component(.day, from: details.start!) == 6)
 precondition(InsuranceDetails(text: "Unreadable").expiry == nil)
 print("PASS: uploaded insurance PDF fields and exact cover dates")
 }
}
