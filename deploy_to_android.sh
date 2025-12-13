#!/bin/bash
# Script to deploy page fault tracer to Android device

set -e

echo "=== Android eBPF Page Fault Tracer Deployment ==="

# Check if adb is available
if ! command -v adb &> /dev/null; then
    echo "Error: adb not found. Please install Android SDK platform tools."
    exit 1
fi

# Check if device is connected
if ! adb devices | grep -q "device$"; then
    echo "Error: No Android device connected. Please connect a device and enable USB debugging."
    exit 1
fi

echo "Restarting adb as root..."
adb root || echo "Warning: Could not restart adb as root. Some features may not work."
sleep 2

echo "Pushing files to Android device..."
adb push pagefault_tracer.py /data/local/tmp/
adb push pagefault.bpf.c /data/local/tmp/
adb shell chmod +x /data/local/tmp/pagefault_tracer.py

echo ""
echo "=== Deployment Complete! ==="
echo ""
echo "Files are located at: /data/local/tmp/"
echo ""
echo "To run the tracer on Android:"
echo "  adb shell"
echo "  cd /data/local/tmp"
echo "  python3 pagefault_tracer.py"
echo ""
echo "Or run directly:"
echo "  adb shell 'cd /data/local/tmp && python3 pagefault_tracer.py'"
echo ""
echo "Note: Your Android device must have:"
echo "  - Root access"
echo "  - Python 3 installed"
echo "  - BCC (BPF Compiler Collection) installed"
echo "  - Kernel with eBPF support"
