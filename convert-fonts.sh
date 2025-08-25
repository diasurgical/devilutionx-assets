#!/usr/bin/env bash

set -euo pipefail

# Requires `idiffs` from the `openimageio-tools` package.
# In your home directory, run:
# git clone https://github.com/diasurgical/devilutionx-font-converter.git
readonly DEVILUTIONX_FONT_CONVERTER_PATH="${HOME}/devilutionx-font-converter"

# The base language to use for CJK fonts.
# This should be the language that has the most identical output files
# in common with other CJK locales.
readonly BASE_CJK_LANG=ja

readonly OUT_DIR=tmp/out

# For debugging
readonly KEEP_PNG=0

declare -ra FONT_PARAMS=(
  # font_filename_prefix font_size frame_height bevel_size supersampling
  12:17:20:1:2
  24:24:32:1:2
  30:30:38:1:2
  42:42:54:2:2
  46:46:64:2.5:2
)

check_deps() {
  if ! which idiff > /dev/null; then
    echo >&2 "Missing idiff. On Debian/Ubuntu, run: "
    echo >&2 "  sudo apt install openimageio-tools"
    exit 1
  fi
  if [[ ! -d "$DEVILUTIONX_FONT_CONVERTER_PATH" ]]; then
    echo >&2 "Missing $DEVILUTIONX_FONT_CONVERTER_PATH. Run: "
    echo >&2 "  git clone https://github.com/diasurgical/devilutionx-font-converter.git ~/devilutionx-font-converter"
    exit 1
  fi
}

maybe_dl() {
  local -r url="$1"
  local -r filename="${url##*/}"
  if [[ ! -f "tmp/dl/${filename}" ]]; then
    set -x
    curl -L --output "tmp/dl/${filename}" --create-dirs --progress-bar "$1"
    { set +x; } 2> /dev/null

    # If filename ends with ".zip", decompress the archive:
    if [[ "${filename}" == *.zip ]]; then
      set -x
      unzip -o "tmp/dl/${filename}" -d "tmp/dl/"
      { set +x; } 2> /dev/null
    fi
  fi
}

download_fonts() {
  maybe_dl https://github.com/notofonts/noto-cjk/releases/download/Sans2.004/06_NotoSansCJKjp.zip
  maybe_dl https://github.com/notofonts/noto-cjk/releases/download/Sans2.004/07_NotoSansCJKkr.zip
  maybe_dl https://github.com/notofonts/noto-cjk/releases/download/Sans2.004/08_NotoSansCJKsc.zip
  maybe_dl https://github.com/notofonts/noto-cjk/releases/download/Sans2.004/09_NotoSansCJKtc.zip

  # We don't have a Cantonese translation yet, so skip converting Cantonese fonts for now.
  # maybe_dl https://github.com/notofonts/noto-cjk/releases/download/Sans2.004/10_NotoSansCJKhk.zip
}

dfc() {
  set -x
  uv --directory="$DEVILUTIONX_FONT_CONVERTER_PATH" run devilutionx-font-converter "$@"
  { set +x; } 2> /dev/null
}

convert_cjk() {
  local -r lang="$1"
  local -r font_path="$2"
  local out_dir
  if [[ "$lang" == "$BASE_CJK_LANG" ]]; then
    out_dir="$OUT_DIR"
  else
    out_dir="${OUT_DIR}/${1}"
  fi
  mkdir -p "$out_dir"

  for params_str in "${FONT_PARAMS[@]}"; do
    IFS=':' read -r font_filename_prefix font_size frame_height bevel_size supersampling <<< "${params_str}"
    dfc \
      --font_path "${PWD}/${font_path}" \
      --output_directory="${PWD}/${out_dir}" \
      --output_basename_prefix="$font_filename_prefix" \
      --save_png \
      --font_size="$font_size" \
      --frame_height="$frame_height" \
      --min_cp=0x4e00 \
      --max_cp=0xff00 \
      --outer_bevel_size="$bevel_size" \
      --supersampling="$supersampling"
    if [[ "$lang" != "$BASE_CJK_LANG" ]]; then
      rm_duplicate_files "$out_dir" "$font_filename_prefix"
      if (( KEEP_PNG == 0 )); then
        rm "$out_dir"/*.png
      fi
    fi
  done
}

rm_duplicate_files() {
  local -r out_dir="$1"
  local -r prefix="$2"
  cd "$out_dir"
  local -a to_remove=()
  for f in "$prefix"-*.pcx; do
    if cmp -s "$f" ../"${f}" || \
       idiff -q -fail 0.87 "${f%.pcx}.png" "../${f%.pcx}.png" 2>/dev/null; then
      to_remove+=(
        "$f"
        "${f%.pcx}.txt"
      )
    fi
  done
  if (( ${#to_remove[@]} )); then
    set -x
    rm -f "${to_remove[@]}"
    { set +x; } 2> /dev/null
  fi
  cd -
}

main() {
  check_deps
  download_fonts

  # The "$BASE_CJK_LANG" must be converted first.
  convert_cjk ja tmp/dl/NotoSansCJKjp-Regular.otf
  convert_cjk ko tmp/dl/NotoSansCJKkr-Regular.otf
  convert_cjk zh_CN tmp/dl/NotoSansCJKsc-Regular.otf
  convert_cjk zh_TW tmp/dl/NotoSansCJKtc-Regular.otf

  if (( KEEP_PNG == 0 )); then
    rm "$OUT_DIR"/*.png
  fi
}

main "$@"
