# Find PageFault on Android OS with eBPF Code

A powerful eBPF-based page fault tracer for Android and Linux systems. This tool allows you to monitor and analyze page faults in real-time, providing detailed information about memory access patterns and potential performance issues.

> **🚀 Quick Start**: New to this tool? Check out the [QUICKSTART.md](QUICKSTART.md) guide to get up and running in minutes!

## Overview

Page faults occur when a program tries to access memory that is not currently in RAM. This tool uses eBPF (extended Berkeley Packet Filter) to trace these events with minimal overhead, making it ideal for performance analysis and debugging on Android devices.

## Features

- **Real-time Tracing**: Monitor page faults as they happen
- **Detailed Information**: Capture PID, TID, process name, fault address, instruction pointer, and error codes
- **User and Kernel Space**: Trace both user-space and kernel-space page faults
- **Filtering**: Filter by process ID or fault type
- **Low Overhead**: eBPF ensures minimal performance impact
- **Android Support**: Designed to work on rooted Android devices

## Architecture

```
┌─────────────────────────────────────────┐
│         User Space                      │
│  ┌───────────────────────────────────┐  │
│  │   pagefault_tracer.py (Python)    │  │
│  │   - Loads eBPF program            │  │
│  │   - Reads events                  │  │
│  │   - Formats output                │  │
│  └──────────────┬────────────────────┘  │
│                 │ BCC/eBPF API          │
├─────────────────┼─────────────────────────┤
│  Kernel Space   │                       │
│  ┌──────────────▼────────────────────┐  │
│  │   pagefault.bpf.c (eBPF/C)       │  │
│  │   - Hooks tracepoints            │  │
│  │   - Captures fault data          │  │
│  │   - Sends to user space          │  │
│  └──────────────┬────────────────────┘  │
│                 │                       │
│  ┌──────────────▼────────────────────┐  │
│  │   Kernel Tracepoints             │  │
│  │   - page_fault_user              │  │
│  │   - page_fault_kernel            │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

## Requirements

### For Linux Desktop/Server

- Linux kernel 4.1+ with eBPF support
- Python 3.6 or later
- BCC (BPF Compiler Collection)
- Root/sudo access
- LLVM/Clang (for compilation)

### For Android

- Rooted Android device
- Kernel with eBPF support (Android 9+ typically)
- Python 3 installed on device
- BCC installed on device
- ADB (Android Debug Bridge) for deployment

## Installation

### On Linux

1. **Install dependencies:**

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y python3 python3-pip bpfcc-tools linux-headers-$(uname -r)
sudo pip3 install bcc

# Fedora/RHEL
sudo dnf install -y python3 python3-bcc bcc-tools kernel-devel

# Arch Linux
sudo pacman -S python bcc bcc-tools
```

2. **Clone the repository:**

```bash
git clone https://github.com/celestia19881/Find-PageFault-on-Android-OS-with-eBPF-code.git
cd Find-PageFault-on-Android-OS-with-eBPF-code
```

3. **Make the script executable:**

```bash
chmod +x pagefault_tracer.py
chmod +x deploy_to_android.sh
```

### On Android

1. **Install dependencies on Android device:**
   - You'll need a rooted Android device with BCC and Python 3
   - Some custom ROMs include these by default
   - Alternatively, use tools like Termux with appropriate packages

2. **Deploy using the provided script:**

```bash
# Connect your Android device via USB
# Enable USB debugging and root access
./deploy_to_android.sh
```

Or manually:

```bash
adb root
adb push pagefault_tracer.py /data/local/tmp/
adb push pagefault.bpf.c /data/local/tmp/
adb shell chmod +x /data/local/tmp/pagefault_tracer.py
```

## Usage

### Basic Usage

```bash
# Run on Linux (requires root)
sudo ./pagefault_tracer.py

# Run on Android
adb shell
cd /data/local/tmp
python3 pagefault_tracer.py
```

### Command Line Options

```bash
# Trace all page faults
sudo ./pagefault_tracer.py

# Trace page faults for a specific process
sudo ./pagefault_tracer.py -p 1234

# Trace only user-space page faults
sudo ./pagefault_tracer.py --user-only

# Trace only kernel-space page faults
sudo ./pagefault_tracer.py --kernel-only

# Show help
./pagefault_tracer.py -h
```

### Example Output

```
Tracing page faults... Press Ctrl+C to stop
----------------------------------------------------------------------------
[COUNT] TYPE   | PID    TID    | COMM             | ADDRESS            | IP                 | FLAGS
----------------------------------------------------------------------------
[     1] USER   | PID:  1234 TID:  1234 | COMM: myapp          | ADDR: 0x00007f8a4c000000 | IP: 0x00005612a4567890 | FLAGS: NOT_PRESENT | READ | USER
[     2] USER   | PID:  1234 TID:  1235 | COMM: myapp          | ADDR: 0x00007f8a4c001000 | IP: 0x00005612a4567894 | FLAGS: NOT_PRESENT | WRITE | USER
[     3] KERNEL | PID:  1234 TID:  1234 | COMM: myapp          | ADDR: 0xffffffff81000000 | IP: 0xffffffff81234567 | FLAGS: NOT_PRESENT | READ | KERNEL
----------------------------------------------------------------------------
Total page faults traced: 3
```

### Understanding the Output

- **COUNT**: Sequential event number
- **TYPE**: USER (user-space) or KERNEL (kernel-space) fault
- **PID**: Process ID
- **TID**: Thread ID
- **COMM**: Process/thread name (truncated to 16 chars)
- **ADDRESS**: Virtual memory address that caused the fault
- **IP**: Instruction pointer (address of the faulting instruction)
- **FLAGS**: Decoded error code:
  - `NOT_PRESENT` / `PROTECTION`: Page not in memory vs protection violation
  - `READ` / `WRITE`: Type of access
  - `USER` / `KERNEL`: Origin of the fault
  - `INSTRUCTION`: Instruction fetch fault
  - `RESERVED`: Reserved bit set

## Building from Source

### Compile eBPF Object (Optional)

```bash
# Using provided Makefile
make

# Or manually
clang -O2 -target bpf -c pagefault.bpf.c -o pagefault.bpf.o
```

Note: The Python script uses BCC, which compiles the eBPF code at runtime, so pre-compilation is optional.

## How It Works

1. **eBPF Program (`pagefault.bpf.c`)**:
   - Attaches to kernel tracepoints for page faults
   - Hooks: `exceptions:page_fault_user` and `exceptions:page_fault_kernel`
   - Captures fault details (address, PID, error code, etc.)
   - Sends events to user space via perf buffer

2. **User-Space Program (`pagefault_tracer.py`)**:
   - Loads and compiles the eBPF program using BCC
   - Opens perf buffer to receive events
   - Formats and displays the information
   - Provides filtering and formatting options

## Troubleshooting

### "Error: This program must be run as root"
Run with `sudo` or as root user.

### "Error loading BPF program"
- Ensure your kernel has eBPF support: `cat /proc/kallsyms | grep bpf`
- Check kernel version: `uname -r` (should be 4.1+)
- Verify BCC is installed: `python3 -c "import bcc"`

### No events showing
- The tracepoints may not exist on your kernel
- Try triggering page faults by running memory-intensive apps
- Check available tracepoints: `ls /sys/kernel/debug/tracing/events/exceptions/`

### Android-specific issues
- Ensure device is rooted with eBPF support
- Some Android kernels don't have eBPF tracepoints enabled
- Check SELinux status: `getenforce` (may need to set to permissive)

## Use Cases

- **Performance Analysis**: Identify excessive page faulting
- **Memory Access Patterns**: Understand how applications use memory
- **Debugging**: Track down memory-related bugs
- **System Monitoring**: Monitor overall system memory behavior
- **Application Profiling**: Profile memory access of specific apps

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

This project is licensed under the GPL-2.0 License - see the LICENSE file for details.

## References

- [eBPF Documentation](https://ebpf.io/)
- [BCC (BPF Compiler Collection)](https://github.com/iovisor/bcc)
- [Linux Kernel Tracepoints](https://www.kernel.org/doc/html/latest/trace/tracepoints.html)
- [Android eBPF Support](https://source.android.com/devices/architecture/kernel/bpf)

## Author

Created for tracing page faults on Android OS using eBPF technology.

## Acknowledgments

- BCC project for the excellent BPF tooling
- Linux kernel community for eBPF support
- Android team for enabling eBPF on Android