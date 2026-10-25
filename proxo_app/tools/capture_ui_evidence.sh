#!/usr/bin/env bash
set -euo pipefail

# Render production Flutter widgets with isolated fixtures. No live payment or
# authentication API is called by the capture tests.
app_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$app_dir"
flutter_bin="${FLUTTER_BIN:-flutter}"
evidence_dir="${PROXO_EVIDENCE_DIR:-$app_dir/build/ui_audit}"
mkdir -p "$evidence_dir/receipt-pdfs"

# These are the SDK's supported analytics suppression flags.
export FLUTTER_SUPPRESS_ANALYTICS=true
export DASH__SUPPRESS_ANALYTICS=true
export CI=true

"$flutter_bin" test --no-pub --reporter expanded \
  --dart-define="PROXO_CAPTURE_DIR=$evidence_dir" \
  --dart-define="RECEIPT_PDF_CAPTURE=$evidence_dir/receipt-pdfs" \
  | tee "$evidence_dir/flutter-test.log"
