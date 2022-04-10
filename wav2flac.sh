#!/bin/bash
set -euo pipefail

main() {
  set -x
  for lang in "$@"; do
    encode_to_flac "$lang"
  done
  du -sh "$@"
}

encode_to_flac() {
  cd "$1"
  find . -type f -iname '*.wav' -print0 \
    | xargs --max-procs="$(nproc)" -0 -I '{}' \
      flac --force --best --silent --delete-input-file '{}'
  cd -
}

if [[ $# -lt 1 ]]; then
  echo >&2 'Usage: ./wav2flac.sh <locale> [locale ...]'
  exit 64
fi

main "$@"
