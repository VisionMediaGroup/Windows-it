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
capture "Root filesystem capacity and usage" /bin/df -h /

root_info="$(/usr/sbin/diskutil info / 2>&1)"
root_status=$?
printf '\n## Root volume details (serial numbers and UUIDs omitted)\n' >> "$output_path"
printf '%s\n' "$root_info" | /usr/bin/awk -F: '
    /^[[:space:]]*(Device Identifier|Device Node|Volume Name|Mounted|Mount Point|File System Personality|Type \(Bundle\)|APFS Container( Reference)?|APFS Physical Store|Partition Type|Protocol|Device Location|Internal|Solid State|Total Size|Available Space|Volume Used Space|Volume Free Space|Container Total Space|Container Free Space):/ {
        print
    }
' >> "$output_path"
printf '[exit status: %s]\n' "$root_status" >> "$output_path"

container="$(printf '%s\n' "$root_info" | /usr/bin/awk -F: '
    /^[[:space:]]*APFS Container( Reference)?:/ {
        container = $2
        sub(/^[[:space:]]*/, "", container)
    }
    /^[[:space:]]*Device Identifier:/ {
        device = $2
        sub(/^[[:space:]]*/, "", device)
    }
    END {
        if (container ~ /^disk[0-9]+$/) {
            print container
        } else if (device ~ /^disk[0-9]+s[0-9]+/) {
            sub(/s[0-9]+.*$/, "", device)
            print device
        }
    }
')"

resize_limits=""
resize_status=127
case "$container" in
    disk[0-9]*)
        if printf '%s\n' "$container" | /usr/bin/grep -Eq '^disk[0-9]+$'; then
            capture "APFS container layout" /usr/sbin/diskutil apfs list "$container"
            printf '\n## Read-only APFS container resize limits\n$ /usr/sbin/diskutil apfs resizeContainer %s limits\n' "$container" >> "$output_path"
            resize_limits="$(/usr/sbin/diskutil apfs resizeContainer "$container" limits 2>&1)"
            resize_status=$?
            printf '%s\n' "$resize_limits" | redact_uuids >> "$output_path"
            printf '[exit status: %s]\n' "$resize_status" >> "$output_path"
        else
            printf '\n## APFS container diagnostics\nCould not safely identify the root APFS container from diskutil info output.\n' >> "$output_path"
        fi
        ;;
    *)
        printf '\n## APFS container diagnostics\nNo root APFS container reference or usable root device identifier was reported.\n' >> "$output_path"
        ;;
esac

snapshots="$(/usr/sbin/diskutil apfs listSnapshots / 2>&1)"
snapshot_status=$?
printf '\n## APFS snapshots on the root volume\n$ /usr/sbin/diskutil apfs listSnapshots /\n' >> "$output_path"
printf '%s\n' "$snapshots" | redact_uuids >> "$output_path"
printf '[exit status: %s]\n' "$snapshot_status" >> "$output_path"

resize_values="$(printf '%s\n' "$resize_limits" | /usr/bin/awk '
    {
        count = split($0, fields, /\(/)
        bytes = fields[count]
        gsub(/[^0-9]/, "", bytes)
    }
    /Current Physical Store partition size on map:/ {
        current = bytes
    }
    /Minimum \(constrained by file\/snapshot usage\):/ {
        minimum = bytes
    }
    /Recommended minimum \(if used with macOS\):/ {
        recommended = bytes
    }
    END {
        if (current > 0 && minimum > 0 && recommended > 0) {
            printf "%.0f %.0f %.0f\n", current, minimum, recommended
        }
    }
')"

printf '\n## Pre-install space planning (estimates only)\n' >> "$output_path"
if [ "$resize_status" -eq 0 ] && [ -n "$resize_values" ]; then
    set -- $resize_values
    /usr/bin/awk -v current="$1" -v minimum="$2" -v recommended="$3" 'BEGIN {
        printf "Current APFS container size: %.1f GB\n", current / 1000000000
        printf "Minimum from current file/snapshot constraints: %.1f GB\n", minimum / 1000000000
        printf "Recommended minimum when retaining macOS: %.1f GB\n", recommended / 1000000000
        printf "Approximate upper-bound shrink while retaining the recommended minimum: %.1f GB\n", (current - recommended) / 1000000000
    }' >> "$output_path"
    if printf '%s\n' "$snapshots" | /usr/bin/grep -q 'limits the minimum size'; then
        printf 'A listed APFS snapshot is reported as limiting the minimum container size; review the snapshot details before any partitioning decision.\n' >> "$output_path"
    fi
    printf 'These are diskutil estimates, not a recommended Windows partition size or a guarantee of reclaimable space. Do not use the shrink estimate as an install target.\n' >> "$output_path"
else
    printf 'Could not compute a space estimate; review the raw APFS resize-limit and snapshot diagnostics above.\n' >> "$output_path"
fi

capture "System Integrity Protection status" /usr/bin/csrutil status
capture "FileVault status" /usr/bin/fdesetup status

printf 'Read-only diagnostics saved to: %s\n' "$output_path"
printf 'No partitions or volumes were created, resized, erased, or mounted by this tool.\n'
