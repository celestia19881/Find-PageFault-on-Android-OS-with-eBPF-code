#!/usr/bin/env python3
"""
Page Fault Tracer for Android/Linux using eBPF
This tool traces page faults in real-time and displays detailed information.
"""

from bcc import BPF
import ctypes as ct
import argparse
import signal
import sys
import os

# Define the event structure matching the BPF program
class PageFaultEvent(ct.Structure):
    _fields_ = [
        ("pid", ct.c_uint32),
        ("tid", ct.c_uint32),
        ("comm", ct.c_char * 16),
        ("address", ct.c_uint64),
        ("ip", ct.c_uint64),
        ("flags", ct.c_uint32),
        ("error_code", ct.c_uint32),
    ]

# BPF program source - can be loaded from file or inline
BPF_PROGRAM = """
#include <linux/bpf.h>
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_tracing.h>

#define TASK_COMM_LEN 16

struct page_fault_event {
    __u32 pid;
    __u32 tid;
    char comm[TASK_COMM_LEN];
    __u64 address;
    __u64 ip;
    __u32 flags;
    __u32 error_code;
};

struct {
    __uint(type, BPF_MAP_TYPE_PERF_EVENT_ARRAY);
    __uint(key_size, sizeof(__u32));
    __uint(value_size, sizeof(__u32));
} events SEC(".maps");

TRACEPOINT_PROBE(exceptions, page_fault_user) {
    struct page_fault_event event = {};
    __u64 pid_tgid = bpf_get_current_pid_tgid();
    
    event.pid = pid_tgid >> 32;
    event.tid = pid_tgid & 0xFFFFFFFF;
    event.address = args->address;
    event.ip = args->ip;
    event.error_code = args->error_code;
    event.flags = 0;
    
    bpf_get_current_comm(&event.comm, sizeof(event.comm));
    
    events.perf_submit(args, &event, sizeof(event));
    
    return 0;
}

TRACEPOINT_PROBE(exceptions, page_fault_kernel) {
    struct page_fault_event event = {};
    __u64 pid_tgid = bpf_get_current_pid_tgid();
    
    event.pid = pid_tgid >> 32;
    event.tid = pid_tgid & 0xFFFFFFFF;
    event.address = args->address;
    event.ip = args->ip;
    event.error_code = args->error_code;
    event.flags = 1;
    
    bpf_get_current_comm(&event.comm, sizeof(event.comm));
    
    events.perf_submit(args, &event, sizeof(event));
    
    return 0;
}
"""

class PageFaultTracer:
    def __init__(self, pid=None, show_kernel=True, show_user=True):
        self.pid = pid
        self.show_kernel = show_kernel
        self.show_user = show_user
        self.event_count = 0
        self.bpf = None
        
    def decode_error_code(self, error_code):
        """Decode page fault error code flags"""
        flags = []
        if error_code & 0x1:
            flags.append("PROTECTION")
        else:
            flags.append("NOT_PRESENT")
        
        if error_code & 0x2:
            flags.append("WRITE")
        else:
            flags.append("READ")
        
        if error_code & 0x4:
            flags.append("USER")
        else:
            flags.append("KERNEL")
        
        if error_code & 0x8:
            flags.append("RESERVED")
        
        if error_code & 0x10:
            flags.append("INSTRUCTION")
        
        return " | ".join(flags) if flags else "NONE"
    
    def print_event(self, cpu, data, size):
        """Callback to handle page fault events"""
        event = ct.cast(data, ct.POINTER(PageFaultEvent)).contents
        
        # Filter by PID if specified
        if self.pid and event.pid != self.pid:
            return
        
        # Filter by fault type
        is_kernel = event.flags == 1
        if is_kernel and not self.show_kernel:
            return
        if not is_kernel and not self.show_user:
            return
        
        self.event_count += 1
        
        fault_type = "KERNEL" if is_kernel else "USER"
        error_flags = self.decode_error_code(event.error_code)
        
        print(f"[{self.event_count:6d}] {fault_type:6s} | "
              f"PID: {event.pid:6d} TID: {event.tid:6d} | "
              f"COMM: {event.comm.decode('utf-8', 'replace'):16s} | "
              f"ADDR: 0x{event.address:016x} | "
              f"IP: 0x{event.ip:016x} | "
              f"FLAGS: {error_flags}")
    
    def run(self):
        """Main tracing loop"""
        print("Loading eBPF program...")
        
        try:
            # Load the inline BPF program (BCC format)
            # Note: The separate pagefault.bpf.c file is for reference and
            # manual compilation, but BCC uses the inline program
            self.bpf = BPF(text=BPF_PROGRAM)
        except Exception as e:
            print(f"Error loading BPF program: {e}")
            print("Make sure you have proper permissions (run as root)")
            return 1
        
        print("Attaching to page fault tracepoints...")
        
        # Open perf buffer
        self.bpf["events"].open_perf_buffer(self.print_event)
        
        print("Tracing page faults... Press Ctrl+C to stop")
        print("-" * 140)
        print(f"{'[COUNT]':8s} {'TYPE':6s} | {'PID':6s} {'TID':6s} | {'COMM':16s} | "
              f"{'ADDRESS':18s} | {'IP':18s} | {'FLAGS'}")
        print("-" * 140)
        
        # Poll for events
        try:
            while True:
                self.bpf.perf_buffer_poll()
        except KeyboardInterrupt:
            print("\n" + "-" * 140)
            print(f"Total page faults traced: {self.event_count}")
            
        return 0

def main():
    parser = argparse.ArgumentParser(
        description="Trace page faults on Android/Linux using eBPF",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  ./pagefault_tracer.py                    # Trace all page faults
  ./pagefault_tracer.py -p 1234            # Trace page faults for PID 1234
  ./pagefault_tracer.py --user-only        # Trace only user-space page faults
  ./pagefault_tracer.py --kernel-only      # Trace only kernel-space page faults
        """
    )
    
    parser.add_argument("-p", "--pid", type=int,
                        help="Trace page faults for specific PID only")
    parser.add_argument("--user-only", action="store_true",
                        help="Show only user-space page faults")
    parser.add_argument("--kernel-only", action="store_true",
                        help="Show only kernel-space page faults")
    
    args = parser.parse_args()
    
    # Check if running as root
    if os.geteuid() != 0:
        print("Error: This program must be run as root")
        return 1
    
    show_kernel = not args.user_only
    show_user = not args.kernel_only
    
    tracer = PageFaultTracer(pid=args.pid, show_kernel=show_kernel, show_user=show_user)
    return tracer.run()

if __name__ == "__main__":
    sys.exit(main())
