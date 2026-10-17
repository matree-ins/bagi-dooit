#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
check_dir="$(mktemp -d "${TMPDIR:-/tmp}/bagidooit-checks.XXXXXX")"
trap 'rm -rf "$check_dir"' EXIT
xcrun swiftc -parse-as-library -swift-version 5 -default-isolation MainActor \
  -module-cache-path "$check_dir/modules" \
  "$project_root/JustDooit/Models/ExpenseModel.swift" \
  "$project_root/JustDooit/Models/QuickEntryRequest.swift" \
  "$project_root/JustDooit/Models/SplitParticipant.swift" \
  "$project_root/JustDooit/Models/SplitItem.swift" \
  "$project_root/JustDooit/Models/SplitBillSession.swift" \
  "$project_root/JustDooit/Models/ScannedReceiptItem.swift" \
  "$project_root/JustDooit/Models/ReceiptScanResult.swift" \
  "$project_root/JustDooit/Services/FinancialAdvisor.swift" \
  "$project_root/JustDooit/Services/ExpenseStore.swift" \
  "$project_root/JustDooit/Models/SavingsErrorNotice.swift" \
  "$project_root/JustDooit/Models/SavingsAdviceKey.swift" \
  "$project_root/JustDooit/Services/SavingsAIErrorMessage.swift" \
  "$project_root/JustDooit/Services/SavingsFallback.swift" \
  "$project_root/JustDooit/Models/SavingsSuggestion.swift" \
  "$project_root/JustDooit/Models/GeneratedSavingsSuggestion.swift" \
  "$project_root/JustDooit/Services/SavingsSuggestionProviding.swift" \
  "$project_root/JustDooit/Services/FoundationSavingsProvider.swift" \
  "$project_root/JustDooit/Services/SavingsAIService.swift" \
  "$project_root/Tests/MockSavingsProvider.swift" \
  "$project_root/Tests/RegressionChecks.swift" \
  -o "$check_dir/regressions"
"$check_dir/regressions"
