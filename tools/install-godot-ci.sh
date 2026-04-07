#!/usr/bin/env bash
set -euo pipefail

version="${1:-4.6.2}"
status="${2:-stable}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"
install_root="$project_root/.godot-ci/linux/${version}-${status}"
download_root="$project_root/.godot-ci/downloads/${version}-${status}"
template_root="$HOME/.local/share/godot/export_templates/${version}.${status}"
release_root="https://github.com/godotengine/godot-builds/releases/download/${version}-${status}"

mkdir -p "$install_root" "$download_root" "$template_root"

editor_zip="$download_root/Godot_v${version}-${status}_linux.x86_64.zip"
template_tpz="$download_root/Godot_v${version}-${status}_export_templates.tpz"

if [ ! -f "$editor_zip" ]; then
  curl -fL "$release_root/$(basename "$editor_zip")" -o "$editor_zip"
fi

if [ ! -f "$template_tpz" ]; then
  curl -fL "$release_root/$(basename "$template_tpz")" -o "$template_tpz"
fi

unzip -oq "$editor_zip" -d "$install_root"
tmp_templates_dir="$download_root/export_templates_${version}_${status}"
rm -rf "$tmp_templates_dir"
mkdir -p "$tmp_templates_dir"
unzip -oq "$template_tpz" -d "$tmp_templates_dir"

template_source_dir="$tmp_templates_dir"
if [ -d "$tmp_templates_dir/templates" ]; then
  template_source_dir="$tmp_templates_dir/templates"
fi

cp -R "$template_source_dir/." "$template_root/"

godot_bin="$(find "$install_root" -maxdepth 1 -type f -name 'Godot_v*_linux.x86_64' | head -n 1)"
if [ -z "$godot_bin" ]; then
  echo "Godot Linux binary not found after install." >&2
  exit 1
fi

chmod +x "$godot_bin"

if [ -n "${GITHUB_ENV:-}" ]; then
  {
    echo "GODOT_PACKAGE_ROOT=$install_root"
    echo "GODOT_BIN=$godot_bin"
  } >> "$GITHUB_ENV"
fi

echo "GODOT_PACKAGE_ROOT=$install_root"
echo "GODOT_BIN=$godot_bin"
echo "Export templates installed at $template_root"
