#!/bin/bash

set -u
umask 077

usage() {
    printf 'Usage: %s [--output FILE]\n' "$0"
    printf 'Collect read-only macOS, disk, APFS, and boot-security diagnostics.\n'
}

output_path="./windows-it-preflight_$(date -u '+%Y%m%dT%H%M%SZ').txt"

while [ "$#" -gt 0 ]; do
    case "$1" in
        --output)
            if [ "$#" -lt 2 ]; then
                printf 'Error: --output requires a file path.\n' >&2
                exit 2
            fi
            output_path=$2
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            printf 'Error: unknown argument: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [ "$(uname -s)" != "Darwin" ]; then
    printf 'This diagnostic tool only runs on macOS.\n' >&2
    exit 1
fi

if [ -e "$output_path" ] || [ -L "$output_path" ]; then
    printf 'Error: refusing to overwrite an existing path: %s\n' "$output_path" >&2
    exit 1
fi

if ! (set -C; : > "$output_path") 2>/dev/null; then
    printf 'Error: cannot create report file: %s\n' "$output_path" >&2
    exit 1
fi

redact_uuids() {
    /usr/bin/sed -E 's/[[:xdigit:]]{8}(-[[:xdigit:]]{4}){3}-[[:xdigit:]]{12}/<UUID redacted>/g'
}

capture() {
    title=$1
    shift

    printf '\n## %s\n$' "$title" >> "$output_path"
    for arg in "$@"; do
        printf ' %s' "$arg" >> "$output_path"
    done
    printf '\n' >> "$output_path"

    if [ ! -x "$1" ]; then
        printf 'Command unavailable: %s\n[exit status: 127]\n' "$1" >> "$output_path"
        return
    fi

    output="$("$@" 2>&1)"
    status=$?
    printf '%s\n' "$output" | redact_uuids >> "$output_path"
    printf '[exit status: %s]\n' "$status" >> "$output_path"
}

printf '# Windows-it macOS preflight report\n' >> "$output_path"
printf 'Generated (UTC): %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >> "$output_path"
printf 'This report is local only. It is not uploaded or submitted automatically.\n' >> "$output_path"
printf 'Review volume names and disk details before sharing this report.\n' >> "$output_path"

capture "macOS version" /usr/bin/sw_vers
capture "Hardware model identifier" /usr/sbin/sysctl -n hw.model
capture "System architecture" /usr/bin/uname -m
capture "Internal physical disks and partition layout" /usr/sbin/diskutil list internal physical

root_info="$(/usr/sbin/diskutil info / 2>&1)"
root_status=$?
printf '\n## Root volume details (serial numbers and UUIDs omitted)\n' >> "$output_path"
printf '%s\n' "$root_info" | /usr/bin/awk -F: '
    /^[[:space:]]*(Device Identifier|Device Node|Volume Name|Mounted|Mount Point|File System Personality|Type \(Bundle\)|APFS Container Reference|APFS Physical Store|Partition Type|Protocol|Device Location|Internal|Solid State|Total Size|Available Space):/ {
        print
    }
' >> "$output_path"
printf '[exit status: %s]\n' "$root_status" >> "$output_path"

container="$(printf '%s\n' "$root_info" | /usr/bin/awk -F: '
    /^[[:space:]]*APFS Container Reference:/ {
        sub(/^[[:space:]]*/, "", $2)
        print $2
        exit
    }
')"

case "$container" in
    disk[0-9]*)
        if printf '%s\n' "$container" | /usr/bin/grep -Eq '^disk[0-9]+$'; then
            capture "APFS container layout" /usr/sbin/diskutil apfs list "$container"
            capture "Read-only APFS container resize limits" /usr/sbin/diskutil apfs resizeContainer "$container" limits
        else
            printf '\n## APFS resize limits\nCould not safely identify the root APFS container.\n' >> "$output_path"
        fi
        ;;
    *)
        printf '\n## APFS resize limits\nNo root APFS container reference was reported.\n' >> "$output_path"
        ;;
esac

capture "System Integrity Protection status" /usr/bin/csrutil status
capture "FileVault status" /usr/bin/fdesetup status

printf 'Read-only diagnostics saved to: %s\n' "$output_path"
printf 'No partitions or volumes were created, resized, erased, or mounted by this tool.\n'
