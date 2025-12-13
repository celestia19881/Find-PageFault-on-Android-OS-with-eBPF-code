#!/bin/bash
# Example usage on Android device via adb

echo "=== eBPF Page Fault Tracer - Android Examples ==="
echo ""

# Check if adb is available
if ! command -v adb &> /dev/null; then
    echo "Error: adb not found. Please install Android SDK platform tools."
    exit 1
fi

# Check if device is connected
if ! adb devices | grep -q "device$"; then
    echo "Error: No Android device connected."
    exit 1
fi

echo "Device connected!"
echo ""

# Example 1: Basic tracing on Android
echo "Example 1: Trace all page faults on Android (10 seconds)"
echo "Command: adb shell 'cd /data/local/tmp && timeout 10 python3 pagefault_tracer.py'"
echo ""
read -p "Press Enter to run (or Ctrl+C to skip)..."
adb shell 'cd /data/local/tmp && timeout 10 python3 pagefault_tracer.py'
echo ""

# Example 2: Trace a specific Android app
echo "Example 2: Trace page faults for a specific Android app"
echo "First, let's find running apps..."
adb shell ps | grep -E "u0_a|system_server" | head -5
echo ""
read -p "Enter PID to trace (or press Enter to skip): " APP_PID

if [ -n "$APP_PID" ]; then
    echo "Tracing PID: $APP_PID"
    echo "Command: adb shell 'cd /data/local/tmp && timeout 10 python3 pagefault_tracer.py -p $APP_PID'"
    adb shell "cd /data/local/tmp && timeout 10 python3 pagefault_tracer.py -p $APP_PID"
    echo ""
fi

# Example 3: Trace while launching an app
echo "Example 3: Trace while launching an Android app"
echo "Available apps:"
adb shell pm list packages | grep -E "com.android.chrome|com.android.settings|com.android.calculator" | head -5
echo ""
read -p "Enter package name to launch (or press Enter to skip): " PACKAGE

if [ -n "$PACKAGE" ]; then
    echo "Starting tracer in background..."
    adb shell 'cd /data/local/tmp && python3 pagefault_tracer.py' &
    TRACER_PID=$!
    
    sleep 2
    echo "Launching app: $PACKAGE"
    adb shell am start -n "$PACKAGE"
    
    sleep 10
    echo "Stopping tracer..."
    kill $TRACER_PID 2>/dev/null
    echo ""
fi

# Example 4: Save output to file
echo "Example 4: Save page fault trace to file"
echo "Command: adb shell 'cd /data/local/tmp && timeout 30 python3 pagefault_tracer.py > pagefaults.log 2>&1'"
echo ""
read -p "Press Enter to run (or Ctrl+C to skip)..."
adb shell 'cd /data/local/tmp && timeout 30 python3 pagefault_tracer.py > pagefaults.log 2>&1'
echo ""
echo "Pulling log file from device..."
adb pull /data/local/tmp/pagefaults.log .
echo "Log saved to: ./pagefaults.log"
echo ""

echo "=== Android Examples Complete ==="
echo ""
echo "For more information, run: adb shell 'cd /data/local/tmp && python3 pagefault_tracer.py --help'"
