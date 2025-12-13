# Architecture Documentation

## System Architecture

The eBPF Page Fault Tracer consists of two main components that work together to capture and display page fault events:

### 1. Kernel Space Component (pagefault.bpf.c)

This is the eBPF program that runs in kernel space and is responsible for:

- **Hooking into Tracepoints**: Attaches to kernel tracepoints for page fault events
  - `exceptions:page_fault_user` - User-space page faults
  - `exceptions:page_fault_kernel` - Kernel-space page faults
  - `kprobe:do_page_fault` - Fallback kprobe if tracepoints unavailable

- **Data Collection**: Captures the following information for each page fault:
  - Process ID (PID)
  - Thread ID (TID)
  - Process name (COMM)
  - Fault address (virtual memory address)
  - Instruction pointer (IP/RIP)
  - Error code (fault type flags)

- **Data Transmission**: Uses BPF perf event arrays to send events to user space with minimal overhead

### 2. User Space Component (pagefault_tracer.py)

This is the Python application that runs in user space and handles:

- **BPF Program Management**:
  - Loads and compiles the eBPF program using BCC
  - Attaches to appropriate tracepoints
  - Manages the lifecycle of the BPF program

- **Event Processing**:
  - Opens perf buffer to receive events from kernel
  - Decodes binary event data
  - Applies user-specified filters (PID, fault type)

- **Output Formatting**:
  - Decodes error codes into human-readable flags
  - Formats events for display
  - Provides statistics

## Data Flow

```
1. Page Fault Occurs
   │
   ├─> Kernel Exception Handler
   │
   └─> Tracepoint Triggered
       │
       └─> eBPF Program Executes
           │
           ├─> Collect fault data (PID, TID, address, etc.)
           │
           └─> Send to perf buffer
               │
               └─> User Space Python Program
                   │
                   ├─> Read from perf buffer
                   │
                   ├─> Decode event data
                   │
                   ├─> Apply filters
                   │
                   └─> Display formatted output
```

## Component Interactions

### BPF Map Structure

The eBPF program uses a `BPF_MAP_TYPE_PERF_EVENT_ARRAY` to efficiently transfer events:

```c
struct {
    __uint(type, BPF_MAP_TYPE_PERF_EVENT_ARRAY);
    __uint(key_size, sizeof(__u32));
    __uint(value_size, sizeof(__u32));
} events SEC(".maps");
```

### Event Structure

Each page fault event is represented by:

```c
struct page_fault_event {
    __u32 pid;              // Process ID
    __u32 tid;              // Thread ID
    char comm[16];          // Process name
    __u64 address;          // Fault address
    __u64 ip;               // Instruction pointer
    __u32 flags;            // Internal flags (user/kernel)
    __u32 error_code;       // Page fault error code
};
```

### Error Code Decoding

The error code is a bitfield with the following flags:

- Bit 0: **P** (Present) - 0=not present, 1=protection fault
- Bit 1: **W/R** (Write/Read) - 0=read, 1=write
- Bit 2: **U/S** (User/Supervisor) - 0=kernel, 1=user
- Bit 3: **RSVD** (Reserved) - Reserved bit violation
- Bit 4: **I/D** (Instruction/Data) - 0=data, 1=instruction fetch

## Performance Considerations

### Overhead

eBPF provides extremely low overhead tracing:

- **In-kernel processing**: No context switches for each event
- **Efficient data structures**: Ring buffer for event transmission
- **Minimal data copying**: Direct memory mapping where possible
- **JIT compilation**: eBPF programs are JIT-compiled for optimal performance

### Scalability

The tracer can handle high event rates:

- Perf buffers are per-CPU to avoid contention
- Events are batched for efficiency
- Filtering in kernel space reduces data volume

### Safety

eBPF ensures system safety:

- **Verifier**: All eBPF programs are verified before loading
- **Bounded loops**: No infinite loops possible
- **Memory safety**: Cannot access arbitrary kernel memory
- **Graceful failure**: Cannot crash the kernel

## Android-Specific Considerations

### Kernel Support

Android devices need:

- Kernel 4.9+ with CONFIG_BPF_SYSCALL enabled
- Tracepoint support (CONFIG_TRACEPOINTS)
- Debug filesystem mounted at /sys/kernel/debug

### Security

On Android:

- Requires root access (SELinux may need to be permissive)
- BPF programs are subject to Android's security model
- May need to adjust SELinux policies

### Performance

On mobile devices:

- Battery impact is minimal due to eBPF efficiency
- Can be used for real-time profiling without significant overhead
- Suitable for debugging in production environments

## Extension Points

The architecture can be extended to:

1. **Additional Metrics**: Capture more data (CPU time, stack traces)
2. **Filtering**: Add kernel-side filtering to reduce overhead
3. **Aggregation**: Add BPF maps for aggregating statistics
4. **Visualization**: Create real-time dashboards
5. **Integration**: Export data to monitoring systems

## Security Considerations

### Privileges

- Requires CAP_BPF or CAP_SYS_ADMIN capabilities
- Should be run with minimal necessary privileges
- On Android, requires root access

### Data Exposure

- Can expose process information (PIDs, names)
- Memory addresses could aid in exploits (ASLR bypass)
- Should be used carefully in production

### Mitigation

- Filter sensitive processes if needed
- Limit access to the tracer
- Use appropriate SELinux contexts on Android
