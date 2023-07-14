#!/bin/bash

set -euo pipefail

declare -ra LANGS=(pl ru)

main() {
  set -x
  build_fonts_mpq
  for lang in "${LANGS[@]}"; do
    build_audio_mpq "$lang"
  done
  du -sh *.mpq
}

build_fonts_mpq() {
  if ! which pcx2clx; then
    echo "Please install pcx2clx from https://github.com/diasurgical/devilutionx-graphics-tools/"
    exit 1
  fi
  rm -f fonts.mpq
  mkdir -p build/fonts
  cp assets/fonts/VERSION build/fonts/VERSION

  FONT_CONVERT_ARGS=(--transparent-color 1 --num-sprites 256 --output-dir build/fonts --quiet)
  for path in assets/fonts/*.pcx; do
    if [[ -f "${path%.pcx}.txt" ]]; then
      pcx2clx "${FONT_CONVERT_ARGS[@]}" --crop-widths "$(cat "${path%.pcx}.txt" | paste -sd , -)" "${path}"
    else
      pcx2clx "${FONT_CONVERT_ARGS[@]}" "${path}"
    fi
  done

  cd build
  find fonts -type f -printf "%p\n" | LC_ALL=C sort | xargs smpq -A -M 1 -C BZIP2 -c ../fonts.mpq
  cd -
}

build_audio_mpq() {
  encode_to_mp3 "$1"
  build_encoded_audio_mpq "$1"
}

encode_to_mp3() {
  rm -rf build/"$1"
  mkdir -p build/"$1"
  cd "$1"
  find * -type f -iname '*.flac' -printf '%h\n' | sort | uniq \
    | xargs -I'{}' mkdir -p ../build/"$1"/'{}'
  find * -type f -iname '*.flac' -print0 \
    | xargs --max-procs="$(nproc)" -0 -I '{}' \
      sh -c 'f={}; flac --silent -d -c "$f" | lame --replaygain-accurate --quiet -q 0 - "../build/'"$1"'/${f%.*}.mp3"'
  cd -
  du -sh build/"$1"
}

build_encoded_audio_mpq() {
  rm -f "$1".mpq
  cp "$1"/credits-translation.txt build/"$1"/
  cd build/"$1"
  find * -type f -printf "%p\n" | LC_ALL=C sort | xargs smpq -A -M 1 -C none -c ../../"$1".mpq
  cd -
}

main "$@"
