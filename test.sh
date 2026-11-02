#!/usr/bin/env bash
# Checks that ray.tga is byte-identical to the image raytracing-bend2 and
# raytracing-goose write, at 1 and 4 samples per pixel, on 1 thread and on all.
set -euo pipefail
cd "$(dirname "$0")"
nim c --hints:off -o:ray main.nim

expect() {
  local got
  got=$(sha256sum ray.tga | cut -d' ' -f1)
  if [[ $got == "$1" ]]; then echo "ok   $2"; else echo "FAIL $2"; fail=1; fi
}

fail=0
./ray 1 --threads 1 >/dev/null
expect b5fac3add377b40d3be30b5faf42446996ad6ff0e6438455323400c991cae5fe "1 spp, 1 thread"
./ray 4 >/dev/null
expect 0ebc7bc784ecd46fd0034b1fb26c51fc1842aa085eab967d6a8e06fef7d37f00 "4 spp, all threads"
exit $fail
