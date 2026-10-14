# Motorhome Companion

One SwiftUI app for iPhone, iPad and a native Mac version, with local SwiftData storage and private CloudKit sync. Requires iOS/iPadOS 17 or later or macOS 14 or later. Built using Xcode 27.0.

## Open and run

Open `Motorhome Companion.xcodeproj` from this folder and choose the **Motorhome Companion** scheme.

- **Mac:** choose **My Mac** (the native macOS destination) and press **⌘R**.
- **iPad simulator:** choose an installed iPad simulator and press **⌘R**. Xcode 27 displays simulators through Device Hub.
- **iPhone simulator:** choose an installed iPhone simulator and press **⌘R**.
- **Your iPhone or iPad:** connect it to the Mac, unlock it and approve Trust This Computer. Add your Apple Account in **Xcode > Settings > Apple Accounts**. Select the project, the Motorhome Companion target, then **Signing & Capabilities**. Keep automatic signing enabled and select your team. Choose the device as the run destination, enable Developer Mode on it if prompted, and press **⌘R**.

Do not create separate projects: all three versions use the same models, screens, app identifier and iCloud container. The Mac and wide iPad layouts use a sidebar; iPhone and narrow iPad layouts use tabs. On Mac, right-click a row for deletion and checklist move-up/move-down commands. Editing forms have Mac-sized windows. The app icon includes Mac sizes.

## Required iCloud setup in your Apple developer account

**The code is configured for iCloud, but live syncing is not yet verified.** An active Apple Developer Program membership is required for CloudKit. A free Personal Team cannot provision this capability. You must sign in and complete account or membership actions yourself.

1. In Xcode, select the **Motorhome Companion** target and your paid developer **Team** under **Signing & Capabilities**. Preserve automatic signing.
2. Add or check **iCloud**, enable **CloudKit**, and register/select this exact container:
   `iCloud.com.MarkHoldsworth.Motorhome-Companion`
3. Use that same container and team for both macOS and iOS. If the identifier is unavailable to your team, choose one you own and change it in `Sync/SyncMonitor.swift` and both `.entitlements` files. Keep these three values identical.
4. Add/check **Push Notifications** for both platforms. For iOS, check **Background Modes > Remote notifications**. The entitlements and the iOS Info.plist already request these capabilities, but the app identifiers and development provisioning profiles must grant them. Xcode's automatic signing can manage profiles after the capabilities are registered.
5. Run a signed **Debug** build on the device holding your existing data. Use the same Apple Account in **device iCloud settings** on your iPhone, iPad and Mac. This is separate from the developer account used to sign the build. Enable iCloud access for the app if device settings offer that switch.
6. Open **My Motorhome > iCloud Sync**. Check the account and wait for a successful upload. Keep the app open and connected initially. The first sync may take time.
7. Install the same Debug build on your other devices. On a fresh installation, leave **Connect your motorhome** open. Do **not** choose **Create my first motorhome** on the additional devices: the existing records will arrive through iCloud.
8. If you have never used the app on any device, choose **Create my first motorhome** on one device only, confirm, then wait for upload before connecting the others.

If you already used older offline copies independently on several devices, they may contain separate copies of the same starter records. CloudKit preserves those independent records; it does not deduplicate them by their text. Review those copies after syncing rather than deleting an installation that may hold unique notes.

### Development versus release

Debug builds use the CloudKit **Development** environment. Release builds use **Production**. Those are separate databases and do not exchange data. Before TestFlight or App Store distribution, use Apple's CloudKit Console to deploy the app's development schema to Production. Apple account setup, provisioning, schema deployment and distribution have not been performed by this coding session. Do not switch environments expecting your development test data to appear in production.

Sources:
- [Apple: Syncing SwiftData across a person's devices](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices)
- [Apple: Enabling CloudKit](https://developer.apple.com/documentation/cloudkit/enabling-cloudkit-in-your-app)
- [Apple: Running on a simulator or device](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices)

## What sync does

Checklists and their progress, vehicle details, dated mileage, maintenance records, trips and daily entries are all in the same private CloudKit-backed store. Changes save locally first, so ordinary editing works offline. Transfers resume when iCloud is available. Deletions sync too; iCloud sync is not a versioned backup.

This implementation syncs devices signed into **one Apple Account**. It does **not** invite Jane's separate Apple Account to share the records. Cross-account sharing would require a separate sharing implementation; never share an Apple Account password as a workaround.

Sync is asynchronous, not instant. Avoid editing the same record simultaneously on different devices. CloudKit resolves overlapping changes automatically; there is no manual conflict editor or edit history. The iCloud screen shows account availability, observed transfer errors and successful upload/download times for the current app session. A successful event does not prove that every other device has downloaded all changes. The account-check button checks account availability; it does not force a transfer.

## Protecting your existing records

The original local database path is retained. Model changes use defaults and optional relationships compatible with CloudKit and a lightweight migration; migration was tested against the original app schema with edited records. Before opening an existing database for this upgrade, the app takes a consistent SQLite backup, including committed WAL data. It is saved beside the store under `Backups/Before-iCloud-v1.sqlite` and is not overwritten. Backup failures stop startup without resetting the original database. There is no user-facing restore tool yet.

New installations no longer automatically seed at launch: an empty local store may simply be awaiting its first iCloud download. Existing records and the original seed marker are preserved. Explicitly creating the first motorhome still saves its starter records and marker together. Create it on one device only to avoid independent seeds.

Do not change your iCloud account while relying on unsynced changes. Let uploads finish first. Account switching is not a supported way to transfer records to another person.

## Using the app

- **Checklists:** choose Arrival or Departure; tap a reminder to tick it, pencil to edit, or plus to add. On iPhone/iPad, Edit reveals reorder handles and swipe-left reveals Delete. On Mac, right-click for move and delete commands. Reset affects only the selected checklist after confirmation.
- **My Motorhome:** tap a detail to edit. Blanks display Not recorded. The mileage is a dated snapshot. Include units and axle/load conditions when recording pressures or limits. The iCloud status screen is here too.
- **Maintenance:** the plus menu adds a maintenance record or uploads an insurance certificate PDF. Insurance uploads create a draft with extracted provider/broker, policy numbers, registration, policyholder, cover start and expiry; review and save to create the entry. The original PDF stays attached and can be viewed or replaced. Unreadable fields can be entered manually, and insurance does not require mileage. Plus adds a maintenance record; choose **Upload MOT from Photos** to attach a certificate and read its registration, test number, result, test date, mileage in miles and printed expiry date on-device. Review and correct the extracted fields before saving; unreadable details require manual entry. Tap the attached image to view the certificate. The printed expiry populates the next due date (no renewal interval is inferred). Photos are stored with the maintenance record; live photo sync needs the same CloudKit verification as other data. tap to edit; swipe or right-click to delete. Enter whole miles without commas and costs such as `1599.20`. Due dates and mileages are your own values, not assumed service intervals.
- **Trips:** add a trip, open it, and add daily entries including campsite ratings and Angus moments. The sample is labelled fictional. Deleting a trip deletes its entries after confirmation.

Forms use drafts so Cancel leaves records unchanged. Saves are explicit with a visible error and rollback if local saving fails. Costs are stored as integer pence. Native controls and semantic text sizes support light/dark appearance and accessibility.

## Verification and developer checks

Verified during this update:

- Native macOS build and iPhone/iPad simulator build succeeded.
- Mac and iPad app processes launched in explicit local test mode (no CloudKit account required).
- Compiled iOS Info.plist contains the remote-notification background mode; Mac icon is included.
- Original-schema migration preserves edited records, completion state, relationships and the seed marker; the pre-upgrade backup is retained without overwriting it.
- On-disk persistence, independent arrival/departure progress, deletion persistence, trip-entry cascade deletion, seed idempotency and numeric validation pass.
- Cloud schema checks confirm optional/default attributes, optional relationships, working inverses and no unique or deny constraints.

**Not verified:** a signed live CloudKit upload/download round trip, account switching, production schema deployment, real-device behaviour or a full interactive accessibility/UI pass. These require configured Apple accounts and devices. Successful builds alone do not establish that iCloud is working.

From Terminal in this folder:

```sh
xcrun swiftc -parse-as-library 'Motorhome Companion/Models/Models.swift' Checks/PersistenceChecks.swift -o /tmp/MotorhomePersistenceChecks
/tmp/MotorhomePersistenceChecks
sh Checks/run-migration-checks.sh
xcrun swiftc -parse-as-library 'Motorhome Companion/Models/Models.swift' Checks/CloudSchemaChecks.swift -o /tmp/MotorhomeCloudSchemaChecks
/tmp/MotorhomeCloudSchemaChecks
```

For an unsigned local-only UI check, add `-local-testing` to **Product > Scheme > Edit Scheme > Run > Arguments Passed On Launch** in a Debug build. This explicitly disables CloudKit and labels the app as Local test mode. Remove the argument before testing sync. It uses the normal local store: do not create extra starter records on devices that will later join an existing cloud database. Release builds ignore this argument. Unsigned command-line builds also need `CODE_SIGNING_ALLOWED=NO`.

Build commands:

```sh
xcodebuild -project 'Motorhome Companion.xcodeproj' -scheme 'Motorhome Companion' -destination 'platform=macOS' -derivedDataPath /tmp/MotorhomeMac CLANG_ENABLE_STAT_CACHE=NO CODE_SIGNING_ALLOWED=NO build
xcodebuild -project 'Motorhome Companion.xcodeproj' -scheme 'Motorhome Companion' -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/MotorhomeCompanionVerified CLANG_ENABLE_STAT_CACHE=NO CODE_SIGNING_ALLOWED=NO build
```

`CLANG_ENABLE_STAT_CACHE=NO` avoids an SDK-cache stall encountered on this machine; it only affects a build optimisation.

### Live acceptance check after provisioning

1. On the original device, tick an arrival item, edit one maintenance note and add a trip entry. Wait for an upload.
2. On the second device, confirm those exact edits arrive, the Departure progress remains separate, and no extra starter trip/checklists appeared.
3. Edit the entry on the second device; check that it returns to the first.
4. Disconnect one device from the network, edit, close and reopen it. Confirm local persistence, reconnect, then confirm the edit on the other device.
5. Delete a disposable test entry, confirm deletion, and verify it disappears on the other device.
6. Repeat with Mac, iPad and iPhone. Test dark mode, large text and VoiceOver separately.

## Remaining scope

Reminder notifications, export/restore UI and sharing between different Apple Accounts are not included. No login system of our own, subscriptions, advertising or third-party backend is used. iCloud is Apple's service and requires connectivity for transfers. Vehicle figures and checklist text are personal reminders, not manufacturer instructions.
