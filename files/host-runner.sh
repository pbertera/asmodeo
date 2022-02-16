#!/bin/sh
set -o errexit
set -o nounset

executable="$(basename "$0")"

if [ "$(basename "$(realpath "$0")")" = "${executable}" ]; then
  echo "can't run ${executable} via ${executable}" >&2
  exit 1
fi

# This seems like the best way to detect if we're inside a toolbox container.
if [ -n "${TOOLBOX_PATH:-}" ]; then
  set -x
  exec flatpak-spawn --host "${executable}" "$@"
fi

# Otherwise do a little dance to find the executable that would have run if not
# for $0 being on the path, and run that instead.
executable="$(
  # Remove this script's directory from PATH; this assumes that you'll never want
  # to run a sibling via this script.
  dir="$(dirname "$0")"
  PATH="$(echo "${PATH}" | sed "s+:${dir}:++")"
  PATH="$(echo "${PATH}" | sed "s+${dir}:++")"
  PATH="$(echo "${PATH}" | sed "s+:${dir}++")"
  command -v "${executable}"
)"

exec "${executable}" "$@"
