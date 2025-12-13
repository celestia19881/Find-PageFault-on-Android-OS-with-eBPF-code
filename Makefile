# Makefile for eBPF Page Fault Tracer
# For Android/Linux systems

# Compiler and flags
CLANG := clang
LLC := llc
CFLAGS := -O2 -g -Wall -Werror

# Try to find BPF headers in common locations
BPF_INCLUDE := $(shell if [ -d /usr/include/bpf ]; then echo "-I/usr/include/bpf"; fi)
BPF_CFLAGS := -target bpf -D__BPF_TRACING__ -I/usr/include $(BPF_INCLUDE)

# Target architecture (adjust for Android if needed)
ARCH := $(shell uname -m | sed 's/x86_64/x86/' | sed 's/aarch64/arm64/')

# Output files
BPF_OBJ := pagefault.bpf.o
VMLINUX_H := vmlinux.h

.PHONY: all clean install deploy-android help

all: $(BPF_OBJ)

# Build eBPF object file
$(BPF_OBJ): pagefault.bpf.c
	@echo "Building eBPF program..."
	$(CLANG) $(BPF_CFLAGS) -c $< -o $@
	@echo "eBPF program built successfully!"

# Generate vmlinux.h (optional, for CO-RE approach)
$(VMLINUX_H):
	@echo "Generating vmlinux.h..."
	@if command -v bpftool > /dev/null; then \
		bpftool btf dump file /sys/kernel/btf/vmlinux format c > $(VMLINUX_H); \
		echo "vmlinux.h generated successfully!"; \
	else \
		echo "Warning: bpftool not found, skipping vmlinux.h generation"; \
	fi

# Install Python dependencies
install:
	@echo "Installing dependencies..."
	@if command -v pip3 > /dev/null; then \
		pip3 install bcc; \
	else \
		echo "Error: pip3 not found. Please install Python 3 and pip."; \
		exit 1; \
	fi
	@echo "Dependencies installed successfully!"

# Deploy to Android device (requires adb)
deploy-android:
	@echo "Deploying to Android device..."
	@if ! command -v adb > /dev/null; then \
		echo "Error: adb not found. Please install Android SDK platform tools."; \
		exit 1; \
	fi
	@adb root || echo "Warning: Could not restart adb as root"
	@sleep 2
	@adb push pagefault_tracer.py /data/local/tmp/
	@adb push pagefault.bpf.c /data/local/tmp/
	@adb shell chmod +x /data/local/tmp/pagefault_tracer.py
	@echo "Files deployed to /data/local/tmp/ on Android device"
	@echo "Run: adb shell 'cd /data/local/tmp && python3 pagefault_tracer.py'"

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@rm -f $(BPF_OBJ) $(VMLINUX_H)
	@echo "Clean complete!"

# Help target
help:
	@echo "eBPF Page Fault Tracer - Build System"
	@echo ""
	@echo "Available targets:"
	@echo "  all             - Build eBPF object file (default)"
	@echo "  install         - Install Python dependencies (bcc)"
	@echo "  deploy-android  - Deploy to Android device via adb"
	@echo "  clean           - Remove build artifacts"
	@echo "  help            - Show this help message"
	@echo ""
	@echo "Usage examples:"
	@echo "  make                    # Build eBPF program"
	@echo "  make install            # Install dependencies"
	@echo "  make deploy-android     # Deploy to Android"
	@echo "  sudo ./pagefault_tracer.py    # Run tracer"
