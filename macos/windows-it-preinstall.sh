#!/bin/bash

set -u

script_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
preflight_script="$script_dir/windows-it-preflight.sh"

if [ ! -f "$preflight_script" ]; then
    printf 'Error: preflight diagnostics script not found: %s\n' "$preflight_script" >&2
    exit 1
fi

printf 'Starting the read-only Windows-it pre-installation checks.\n'
if ! /bin/bash "$preflight_script"; then
    printf 'Preflight checks could not complete. No installation was started.\n' >&2
    exit 1
fi

printf '\nSTOP: the Apple silicon Windows partitioning and installation process is not implemented or validated yet.\n' >&2
printf 'Review the preflight report. No partitions or volumes were modified, and Windows was not installed.\n' >&2
exit 3
