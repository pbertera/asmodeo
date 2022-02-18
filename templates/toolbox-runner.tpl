#!/bin/sh
executable="$(basename "$0")"

# I'm in a toolbox
if [ -f /run/.containerenv ]; then

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
fi

{% if sandbox_tool == "distrobox" %}
exec distrobox enter {{ container }} -- {{ cmd }} $@
{% else %}
exec toolbox run -c {{ container }} {{ cmd }} $@
{% endif %}
