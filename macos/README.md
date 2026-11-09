# macOS preflight diagnostics

`windows-it-preflight.sh` is a read-only information-gathering tool for planning
future Apple Silicon Windows installation work. It records macOS version and
model, internal physical disk layout, root filesystem usage, APFS container
layout and resize limits, root-volume snapshots, System Integrity Protection,
and FileVault status. It resolves the root APFS container from the root device
identifier when macOS does not report a container reference directly. These
checks do not capture the complete Apple boot policy. The report also includes
a planning summary based on `diskutil`'s resize limits and notes when an APFS
snapshot is reported as limiting the minimum size. The calculated shrink
amount is an estimate, not a recommended partition size or guarantee.

Run it from Terminal:

```sh
bash macos/windows-it-preflight.sh
```

To start the pre-installation checks from the repository root, run:

```sh
bash macos/windows-it-preinstall.sh
```

This launcher runs the read-only preflight and then stops intentionally. The
Apple silicon partitioning and Windows installation process is not implemented
or validated, so the launcher will not modify disks or install an operating
system.

For an initial, non-exhaustive troubleshooting list of possible future Windows
Setup errors and blue-screen codes, see
[`WINDOWS-IT-INSTALL-STOP-CODES.txt`](../WINDOWS-IT-INSTALL-STOP-CODES.txt). The
codes are examples, not confirmation that Windows installation is supported
on Apple silicon.

By default, the report is created in the current directory with a timestamped
name. To choose another location, pass `--output FILE`. The tool refuses to
overwrite an existing path and creates the report with owner-only permissions.
It does not use `sudo`, access the network, or create, resize, erase, or mount
any disk or volume. Individual diagnostic command failures are recorded in the
report rather than hidden.

The report is not uploaded or submitted automatically. Review it before sharing:
it redacts UUIDs and avoids serial-number collection, but disk/volume names and
hardware model information may still be identifying.

## Why this comes before partitioning

Asahi Linux's documented layout includes a small APFS stub OS, a FAT32 EFI
System Partition, and OS-specific storage. Apple Silicon's boot flow is not
standard PC UEFI; Asahi also relies on its own boot stages and chainloading
configuration. Matching its partition sizes alone would not make a Windows
boot path work. See the [Asahi platform overview](https://asahilinux.org/docs/platform/introduction/)
and [open OS interoperability design](https://asahilinux.org/docs/platform/open-os-interop/)
for the boot-chain and partition-layout details.

This preflight report is intended to establish the Mac's actual disk and
boot-policy state before any partition-changing implementation is attempted.
It does not configure a Windows boot manager or guarantee fallback to macOS
after a boot failure.

The next partitioning implementation must be tested on supported hardware and
must preserve the existing macOS APFS container. Do not treat this report as a
Windows installation or bootloader compatibility result.
