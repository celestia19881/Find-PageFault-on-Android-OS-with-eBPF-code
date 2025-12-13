#!/bin/bash
# Example usage scenarios for the page fault tracer

echo "=== eBPF Page Fault Tracer - Example Usage ==="
echo ""

# Example 1: Basic tracing
echo "Example 1: Trace all page faults for 10 seconds"
echo "Command: sudo timeout 10 ./pagefault_tracer.py"
echo ""
read -p "Press Enter to run (or Ctrl+C to skip)..."
sudo timeout 10 ../pagefault_tracer.py
echo ""

# Example 2: Trace a specific process
echo "Example 2: Trace page faults for a specific process"
echo "First, let's start a sample process that generates page faults..."
echo ""

# Create a simple memory allocation test program
cat > /tmp/memtest.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main() {
    printf("Memory test program starting (PID: %d)\n", getpid());
    printf("This will generate page faults by allocating memory...\n");
    
    for (int i = 0; i < 5; i++) {
        // Allocate 10MB
        char *ptr = malloc(10 * 1024 * 1024);
        if (ptr) {
            // Touch the memory to cause page faults
            memset(ptr, 0, 10 * 1024 * 1024);
            printf("Allocated and touched 10MB (iteration %d)\n", i + 1);
        }
        sleep(1);
    }
    
    printf("Memory test complete\n");
    return 0;
}
EOF

# Compile it
if gcc /tmp/memtest.c -o /tmp/memtest 2>/tmp/memtest_compile.err; then
    rm -f /tmp/memtest_compile.err
    echo "Starting memory test program in background..."
    /tmp/memtest &
    MEMTEST_PID=$!
    sleep 1
    
    echo "Command: sudo timeout 5 ./pagefault_tracer.py -p $MEMTEST_PID"
    read -p "Press Enter to run (or Ctrl+C to skip)..."
    sudo timeout 5 ../pagefault_tracer.py -p $MEMTEST_PID
    
    # Wait for memtest to finish
    wait $MEMTEST_PID 2>/dev/null
    echo ""
else
    echo "Could not compile memory test program, skipping..."
    if [ -f /tmp/memtest_compile.err ]; then
        echo "Compilation error:"
        cat /tmp/memtest_compile.err
    fi
    echo ""
fi

# Example 3: User-space only
echo "Example 3: Trace only user-space page faults"
echo "Command: sudo timeout 10 ./pagefault_tracer.py --user-only"
echo ""
read -p "Press Enter to run (or Ctrl+C to skip)..."
sudo timeout 10 ../pagefault_tracer.py --user-only
echo ""

# Example 4: Kernel-space only
echo "Example 4: Trace only kernel-space page faults"
echo "Command: sudo timeout 10 ./pagefault_tracer.py --kernel-only"
echo ""
read -p "Press Enter to run (or Ctrl+C to skip)..."
sudo timeout 10 ../pagefault_tracer.py --kernel-only
echo ""

echo "=== Examples Complete ==="
echo ""
echo "For more information, run: ./pagefault_tracer.py --help"
