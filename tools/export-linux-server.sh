#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"
run_dir="$project_root/.codex-run"
build_dir="$run_dir/linux-server"
archive_path="$run_dir/linux-server.tar.gz"
godot_bin="${GODOT_BIN:-}"

if [ -z "$godot_bin" ]; then
  godot_bin="$(find "$project_root/.godot-ci/linux" -type f -name 'Godot_v*_linux.x86_64' | head -n 1)"
fi

if [ -z "$godot_bin" ] || [ ! -f "$godot_bin" ]; then
  echo "Godot Linux binary not found. Run tools/install-godot-ci.sh first." >&2
  exit 1
fi

rm -rf "$build_dir"
mkdir -p "$build_dir"

"$godot_bin" --headless --path "$project_root" --export-release "Linux" "$build_dir/DUEL.x86_64"

if [ ! -f "$build_dir/DUEL.x86_64" ] || [ ! -f "$build_dir/DUEL.pck" ]; then
  echo "Linux server export is incomplete." >&2
  exit 1
fi

chmod +x "$build_dir/DUEL.x86_64"
tar -C "$build_dir" -czf "$archive_path" .

echo "Linux server export complete: $build_dir"
echo "Linux server package: $archive_path"
