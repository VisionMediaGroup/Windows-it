# Windows-it

> ⚠️ IMPORTANT
>
> The current macOS application is a placeholder and is not functional. It exists only as an early development build while the project's architecture, research, and future features are being developed.

> Bringing Windows closer to Apple Silicon through research, documentation, compatibility development, and platform exploration.

## Overview

Windows-it is an experimental project dedicated to investigating the possibility of improving Windows support on Apple Silicon devices.

The project focuses on understanding Apple Silicon hardware, documenting system behavior, researching hardware interfaces, and developing software components that may help bridge the gap between Windows and Apple-designed ARM systems.

This repository serves as the central hub for project documentation, source code, testing results, hardware research, development tools, and community collaboration.

## Why This Project Exists

Apple Silicon has demonstrated impressive performance, power efficiency, and hardware integration. However, Windows support on these devices remains limited compared to traditional PC hardware.

Windows-it aims to explore what is required to improve compatibility by studying:

- Hardware initialization
- Device communication
- Driver requirements
- Boot processes
- Platform firmware behavior
- ARM64 Windows compatibility
- Hardware abstraction methods

The long-term objective is to document and develop the software infrastructure necessary for improved Windows operation on Apple Silicon systems.

## Project Goals

### Research

- Analyze Apple Silicon hardware behavior
- Document device interfaces
- Study system firmware and boot processes
- Investigate platform initialization sequences

### Development

- Build compatibility components
- Create testing utilities
- Develop supporting software tools
- Improve hardware interaction capabilities

### Documentation

- Maintain detailed technical documentation
- Record discoveries and test results
- Provide references for future development

### Community

- Share findings with developers and researchers
- Encourage collaboration and discussion
- Create a knowledge base for future projects

## Current Status

🚧 Early Development

Windows-it is currently in the research and planning phase.

Many components are experimental, incomplete, or under active investigation.

The read-only macOS preflight tool in [`macos/`](macos/README.md) collects disk,
APFS resize-limit, and boot-policy diagnostics to inform future partitioning
work. It does not modify disks or install Windows.

## Repository Structure

```text
/docs        Documentation and research notes
/src         Source code
/tools       Development and testing utilities
/tests       Test results and validation
/assets      Images, diagrams, and resources
