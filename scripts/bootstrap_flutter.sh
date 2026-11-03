#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || { echo 'Cần cài Flutter stable >=3.35 trước khi chạy script này.' >&2; exit 1; }
# Generate only missing platform runners; never overwrite app code or user edits.
scaffold_dir=$(mktemp -d)
trap 'rm -rf "$scaffold_dir"' EXIT
if [[ ! -d android || ! -d ios ]]; then
  flutter create --platforms=android,ios --project-name=vstudy --org=io.vstudy --no-pub "$scaffold_dir/vstudy"
  if [[ ! -d android ]]; then cp -R "$scaffold_dir/vstudy/android" android; fi
  if [[ ! -d ios ]]; then cp -R "$scaffold_dir/vstudy/ios" ios; fi
fi
python3 tools/configure_mobile.py
flutter pub get
