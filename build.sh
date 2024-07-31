#!/bin/bash

set -euo pipefail

declare -ra LANGS=(es pl ru)

declare -rA DEPENDENCY_SOURCES=(
  [pcx2clx]=https://github.com/diasurgical/devilutionx-graphics-tools/
)
declare -ra DEPENDENCIES=(pcx2clx flac lame)

check_deps() {
  local -a missing_deps=()
  local path
  for dep in "${DEPENDENCIES[@]}"; do
    if path="$(which "$dep")"; then
      echo >&2 "Using $dep from $path"
    else
      missing_deps+=("$dep")
    fi
  done
  if (( ${#missing_deps[@]} )); then
    echo >&2 "Error: Missing dependencies"
    for dep in "${missing_deps[@]}"; do
      echo >&2 '* '"Please install \"${dep}\" from ${DEPENDENCY_SOURCES[$dep]:-your package manager}"
    done
    exit 1
  fi
}

main() {
  check_deps
  set -x
  build_fonts_mpq
  for lang in "${LANGS[@]}"; do
    build_audio_mpq "$lang"
  done
  du -sh *.mpq
}

build_fonts_mpq() {
  rm -f fonts.mpq
  mkdir -p build/fonts
  cp assets/fonts/VERSION build/fonts/VERSION

  FONT_CONVERT_ARGS=(--transparent-color 1 --num-sprites 256 --quiet)
  for path in assets/fonts/*.pcx; do
    if [[ -f "${path%.pcx}.txt" ]]; then
      pcx2clx "${FONT_CONVERT_ARGS[@]}" --output-dir build/fonts --crop-widths "$(cat "${path%.pcx}.txt" | paste -sd , -)" "${path}"
    else
      pcx2clx "${FONT_CONVERT_ARGS[@]}" --output-dir build/fonts "${path}"
    fi
  done
  for lang_dir in fonts/*/; do
    lang_dir="${lang_dir%/}" # remove trailing slash
    if [[ $lang_dir = 'fonts/*' ]]; then
      # glob didn't match
      continue
    fi
    mkdir -p "build/${lang_dir}"
    for path in "$lang_dir"/*.pcx; do
      if [[ -f "${path%.pcx}.txt" ]]; then
        pcx2clx "${FONT_CONVERT_ARGS[@]}" --output-dir "build/${lang_dir}" --crop-widths "$(cat "${path%.pcx}.txt" | paste -sd , -)" "${path}"
      else
        pcx2clx "${FONT_CONVERT_ARGS[@]}" --output-dir "build/${lang_dir}" "${path}"
      fi
    done
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
