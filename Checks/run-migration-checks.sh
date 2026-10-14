#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
check_dir=$(mktemp -d /tmp/MotorhomeMigration.XXXXXX)
trap 'rm -rf "$check_dir"' EXIT
xcrun swiftc -parse-as-library Checks/Fixtures/LegacyModels.swift Checks/LegacyMigrationWriter.swift -o "$check_dir/write-legacy"
xcrun swiftc -parse-as-library 'Motorhome Companion/Models/Models.swift' 'Motorhome Companion/Sync/StoreBackup.swift' Checks/MigrationChecks.swift -o "$check_dir/check-migration"
"$check_dir/write-legacy" "$check_dir/legacy.store"
"$check_dir/check-migration" "$check_dir/legacy.store"
