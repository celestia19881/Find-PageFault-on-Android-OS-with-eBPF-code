# Quick Start Guide

Get up and running with the eBPF Page Fault Tracer in minutes!

## TL;DR

```bash
# On Linux (requires root)
sudo ./pagefault_tracer.py

# On Android (requires rooted device with eBPF support)
./deploy_to_android.sh
adb shell 'cd /data/local/tmp && python3 pagefault_tracer.py'
```

## Prerequisites Check

Before you start, verify your system meets the requirements:

### Linux Desktop/Server

```bash
# Check kernel version (need 4.1+)
uname -r

# Check if eBPF is supported
cat /proc/kallsyms | grep bpf_prog_load

# Check if Python 3 is installed
python3 --version

# Check if BCC is installed
python3 -c "import bcc; print('BCC version:', bcc.__version__)"
```

### Android Device

```bash
# Check if device is connected
adb devices

# Check if device has root
adb shell su -c id

# Check kernel version
adb shell uname -r

# Check if Python 3 is available on device
adb shell python3 --version
```

## Installation

### Option 1: On Linux (Recommended)

1. **Install BCC and dependencies:**

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y python3-bcc bpfcc-tools linux-headers-$(uname -r)

# Fedora/RHEL
sudo dnf install -y python3-bcc bcc-tools kernel-devel

# Arch Linux
sudo pacman -S python bcc bcc-tools
```

2. **Clone and run:**

```bash
git clone https://github.com/celestia19881/Find-PageFault-on-Android-OS-with-eBPF-code.git
cd Find-PageFault-on-Android-OS-with-eBPF-code
chmod +x pagefault_tracer.py
sudo ./pagefault_tracer.py
```

### Option 2: On Android

1. **Ensure your device has:**
   - Root access
   - Kernel with eBPF support (Android 9+)
   - Python 3 and BCC installed (through custom ROM or Termux)

2. **Deploy the tracer:**

```bash
git clone https://github.com/celestia19881/Find-PageFault-on-Android-OS-with-eBPF-code.git
cd Find-PageFault-on-Android-OS-with-eBPF-code
chmod +x deploy_to_android.sh
./deploy_to_android.sh
```

3. **Run on Android:**

```bash
adb shell
cd /data/local/tmp
python3 pagefault_tracer.py
```

## Basic Usage Examples

### Example 1: Trace All Page Faults (5 seconds)

```bash
sudo timeout 5 ./pagefault_tracer.py
```

### Example 2: Trace a Specific Process

Find the PID of your process:
```bash
ps aux | grep myapp
```

Then trace it:
```bash
sudo ./pagefault_tracer.py -p 1234
```

### Example 3: Trace Only User-Space Faults

```bash
sudo ./pagefault_tracer.py --user-only
```

### Example 4: Trace While Running a Program

Terminal 1:
```bash
sudo ./pagefault_tracer.py
```

Terminal 2:
```bash
# Run your application
./my_application
```

## Understanding the Output

```
[COUNT] TYPE   | PID    TID    | COMM             | ADDRESS            | IP                 | FLAGS
[     1] USER   | PID:  1234 TID:  1234 | COMM: myapp          | ADDR: 0x00007f8a4c000000 | IP: 0x00005612a4567890 | FLAGS: NOT_PRESENT | READ | USER
```

- **COUNT**: Event number
- **TYPE**: USER or KERNEL fault
- **PID/TID**: Process and thread IDs
- **COMM**: Process name (max 16 chars)
- **ADDRESS**: Memory address that caused the fault
- **IP**: Instruction pointer (where the fault occurred)
- **FLAGS**: Fault details:
  - `NOT_PRESENT` - Page not in memory (common)
  - `PROTECTION` - Protection violation
  - `READ` / `WRITE` - Type of access
  - `USER` / `KERNEL` - Fault origin
  - `INSTRUCTION` - Instruction fetch fault

## Common Use Cases

### Debug High Memory Usage

```bash
# Find the process
ps aux --sort=-%mem | head -n 5

# Trace its page faults
sudo ./pagefault_tracer.py -p <PID>
```

### Profile Application Startup

```bash
# Start tracing
sudo ./pagefault_tracer.py > /tmp/faults.log &
TRACER_PID=$!

# Launch your app
./my_application

# Stop tracing after 10 seconds
sleep 10
sudo kill $TRACER_PID

# Analyze the log
less /tmp/faults.log
```

### Monitor System-Wide Page Fault Activity

```bash
# Trace for 1 minute and count faults per process
sudo timeout 60 ./pagefault_tracer.py | \
  awk '{print $7}' | sort | uniq -c | sort -rn
```

## Troubleshooting

### "Must be run as root"
```bash
# Add sudo
sudo ./pagefault_tracer.py
```

### "Error loading BPF program"
```bash
# Check kernel support
zcat /proc/config.gz | grep CONFIG_BPF
# or
cat /boot/config-$(uname -r) | grep CONFIG_BPF

# Install kernel headers
sudo apt-get install linux-headers-$(uname -r)  # Ubuntu/Debian
sudo dnf install kernel-devel                   # Fedora/RHEL
```

### No events showing
```bash
# Check if tracepoints exist
ls /sys/kernel/debug/tracing/events/exceptions/

# Generate some page faults
dd if=/dev/zero of=/dev/null bs=1M count=100
```

### Android: Permission denied
```bash
# Ensure root access
adb root
adb shell su -c id

# Check SELinux (may need to be permissive on some devices)
adb shell getenforce
```

## Next Steps

- Read the [full README](README.md) for detailed information
- Check [ARCHITECTURE.md](docs/ARCHITECTURE.md) to understand how it works
- See [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for detailed troubleshooting
- Try the example scripts in the `examples/` directory

## Getting Help

If you encounter issues:

1. Check the [troubleshooting guide](docs/TROUBLESHOOTING.md)
2. Verify your kernel has eBPF support
3. Ensure BCC is properly installed
4. Check kernel logs: `dmesg | grep -i bpf`
5. Open an issue on GitHub with:
   - Platform and kernel version (`uname -r`)
   - BCC version
   - Full error message
   - Output of `dmesg | grep -i bpf`

## Tips

- Use `Ctrl+C` to stop tracing
- Redirect output to a file for later analysis
- Use `timeout` command to limit tracing duration
- Filter by specific PID to reduce noise
- Start with short traces (5-10 seconds) to verify setup

Happy tracing! 🔍
