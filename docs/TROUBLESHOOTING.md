# Troubleshooting Guide

This guide helps you resolve common issues when using the eBPF Page Fault Tracer.

## Common Issues

### 1. "Error: This program must be run as root"

**Problem**: The tracer requires root privileges to load eBPF programs.

**Solution**:
```bash
# Linux
sudo ./pagefault_tracer.py

# Android
adb root
adb shell 'cd /data/local/tmp && python3 pagefault_tracer.py'
```

### 2. "Error loading BPF program"

**Problem**: The eBPF program failed to load into the kernel.

**Possible Causes and Solutions**:

#### A. Kernel doesn't support eBPF

Check if eBPF is supported:
```bash
# Check for BPF system call
cat /proc/kallsyms | grep bpf_prog_load

# Check kernel version (need 4.1+)
uname -r

# Check kernel config
zcat /proc/config.gz | grep CONFIG_BPF
# or
cat /boot/config-$(uname -r) | grep CONFIG_BPF
```

**Solution**: Upgrade kernel or use a kernel with eBPF support.

#### B. BCC not installed properly

Check BCC installation:
```bash
python3 -c "import bcc; print(bcc.__version__)"
```

**Solution**: 
```bash
# Ubuntu/Debian
sudo apt-get install python3-bcc bpfcc-tools

# Fedora
sudo dnf install python3-bcc bcc-tools

# From source
git clone https://github.com/iovisor/bcc.git
cd bcc
mkdir build && cd build
cmake ..
make
sudo make install
```

#### C. Missing kernel headers

**Solution**:
```bash
# Ubuntu/Debian
sudo apt-get install linux-headers-$(uname -r)

# Fedora
sudo dnf install kernel-devel
```

### 3. No Events Showing

**Problem**: The tracer runs but doesn't display any page faults.

**Possible Causes and Solutions**:

#### A. Tracepoints not available

Check if tracepoints exist:
```bash
ls /sys/kernel/debug/tracing/events/exceptions/
```

**Solution**: Your kernel may not have the required tracepoints. The program attempts to use kprobes as a fallback, but some kernels may not have `do_page_fault` symbol exported.

#### B. Debug filesystem not mounted

Check if debugfs is mounted:
```bash
mount | grep debugfs
```

**Solution**:
```bash
sudo mount -t debugfs none /sys/kernel/debug
```

#### C. No page faults occurring

**Solution**: Generate some page faults to test:
```bash
# Allocate memory
dd if=/dev/zero of=/dev/null bs=1M count=100

# Or run a memory-intensive application
```

### 4. Android-Specific Issues

#### A. "Permission denied" on Android

**Problem**: Cannot access BPF features even with root.

**Solution**:
```bash
# Check SELinux status
adb shell getenforce

# Check if device is rooted
adb shell su -c id
```

**WARNING**: Setting SELinux to permissive mode (`setenforce 0`) significantly reduces system security and should **ONLY** be done on dedicated test/development devices, never on production or personal devices. This disables important security protections. A better approach is to create proper SELinux policies for your tracing needs.

#### B. "python3: command not found"

**Problem**: Python 3 not installed on Android device.

**Solution**: Install Python through Termux or custom ROM, or compile Python for Android.

#### C. "bcc module not found"

**Problem**: BCC not available on Android device.

**Solution**: 
- Use a custom ROM with BCC support
- Build BCC for Android (complex)
- Use alternative eBPF tools like bpftrace

### 5. High CPU Usage

**Problem**: The tracer is using too much CPU.

**Solution**:
- Filter by specific PID: `./pagefault_tracer.py -p <PID>`
- Increase perf buffer size (modify Python code)
- Add rate limiting in the eBPF code

### 6. Missing Events

**Problem**: Events appear to be dropped.

**Solution**:
- Increase perf buffer size in the Python code
- Add print statements to check buffer status
- Reduce system load

### 7. "Invalid argument" Error

**Problem**: BPF program rejected by kernel verifier.

**Solution**:
- Check kernel logs: `dmesg | tail -50`
- Look for verifier errors
- May need to adjust BPF program for your kernel version

## Debugging Steps

### 1. Verbose Mode

Add debugging to the Python script:
```python
# Add at the top after imports
import logging
logging.basicConfig(level=logging.DEBUG)
```

### 2. Check Kernel Logs

```bash
# Real-time kernel logs
sudo dmesg -w

# Recent BPF-related logs
sudo dmesg | grep -i bpf | tail -20
```

### 3. Verify BPF Program

Check if program is loaded:
```bash
# List loaded BPF programs
sudo bpftool prog list

# List BPF maps
sudo bpftool map list
```

### 4. Test Tracepoints Manually

```bash
# Enable tracepoint
echo 1 > /sys/kernel/debug/tracing/events/exceptions/page_fault_user/enable

# Check trace output
cat /sys/kernel/debug/tracing/trace_pipe

# Disable when done
echo 0 > /sys/kernel/debug/tracing/events/exceptions/page_fault_user/enable
```

## Platform-Specific Notes

### Ubuntu/Debian

- Usually works out of the box with proper packages
- May need to add user to `tracing` group

### Fedora/RHEL

- SELinux may interfere
- May need custom policy or set to permissive

### Arch Linux

- Generally works well
- Ensure kernel headers match running kernel

### Android

- Most complex platform
- Requires significant setup
- Not all devices support eBPF
- Best with Android 9+ and custom kernels

## Getting Help

If you're still having issues:

1. Check kernel version: `uname -r`
2. Check BCC version: `python3 -c "import bcc; print(bcc.__version__)"`
3. Check for kernel errors: `dmesg | grep -i bpf`
4. Verify tracepoints: `ls /sys/kernel/debug/tracing/events/exceptions/`
5. Create an issue on GitHub with:
   - Platform and kernel version
   - BCC version
   - Full error message
   - Output of `dmesg | grep -i bpf`

## Additional Resources

- [BCC Reference Guide](https://github.com/iovisor/bcc/blob/master/docs/reference_guide.md)
- [eBPF Documentation](https://ebpf.io/what-is-ebpf)
- [Linux Tracing Systems](https://www.kernel.org/doc/html/latest/trace/index.html)
- [Android eBPF](https://source.android.com/devices/architecture/kernel/bpf)
