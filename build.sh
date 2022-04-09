#!/bin/bash

set -euo pipefail

main() {
  set -x
  build_fonts_mpq
  build_audio_mpq pl
  build_audio_mpq ru
  du -sh *.mpq
}

build_fonts_mpq() {
  rm -f fonts.mpq
  cd assets
  find * -type f -exec smpq -M 1 -C PKWARE -c ../fonts.mpq '{}' '+'
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
  find * -type f -iname '*.wav' -printf '%h\n' | sort | uniq \
    | xargs -I'{}' mkdir -p ../build/"$1"/'{}'
  find * -type f -iname '*.wav' -print0 \
    | xargs --max-procs="$(nproc)" -0 -I '{}' \
      sh -c 'f={}; xargs lame --replaygain-accurate --quiet -q 0 "$f" "../build/'"$1"'/${f%.*}.mp3"'
  cd -
  du -sh build/"$1"
}

build_encoded_audio_mpq() {
  rm -f "$1".mpq
  cp "$1"/credits-translation.txt build/"$1"/
  cd build/"$1"
  find * -type f -exec smpq -M 1 -C none -c ../../"$1".mpq '{}' '+'
  cd -
}

main "$@"
