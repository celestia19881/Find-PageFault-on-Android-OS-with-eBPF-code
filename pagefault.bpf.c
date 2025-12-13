// SPDX-License-Identifier: GPL-2.0
// eBPF program to trace page faults on Android/Linux systems

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

// Tracepoint for page faults
// This hooks into the exceptions:page_fault_user tracepoint
SEC("tracepoint/exceptions/page_fault_user")
int trace_page_fault_user(struct trace_event_raw_page_fault_user *ctx)
{
    struct page_fault_event event = {};
    __u64 pid_tgid = bpf_get_current_pid_tgid();
    
    event.pid = pid_tgid >> 32;
    event.tid = pid_tgid & 0xFFFFFFFF;
    event.address = ctx->address;
    event.ip = ctx->ip;
    event.error_code = ctx->error_code;
    event.flags = 0;
    
    bpf_get_current_comm(&event.comm, sizeof(event.comm));
    
    bpf_perf_event_output(ctx, &events, BPF_F_CURRENT_CPU, 
                          &event, sizeof(event));
    
    return 0;
}

// Alternative tracepoint for kernel page faults
SEC("tracepoint/exceptions/page_fault_kernel")
int trace_page_fault_kernel(struct trace_event_raw_page_fault_kernel *ctx)
{
    struct page_fault_event event = {};
    __u64 pid_tgid = bpf_get_current_pid_tgid();
    
    event.pid = pid_tgid >> 32;
    event.tid = pid_tgid & 0xFFFFFFFF;
    event.address = ctx->address;
    event.ip = ctx->ip;
    event.error_code = ctx->error_code;
    event.flags = 1; // Mark as kernel fault
    
    bpf_get_current_comm(&event.comm, sizeof(event.comm));
    
    bpf_perf_event_output(ctx, &events, BPF_F_CURRENT_CPU, 
                          &event, sizeof(event));
    
    return 0;
}

// Kprobe on do_page_fault as a fallback if tracepoints are not available
SEC("kprobe/do_page_fault")
int kprobe_do_page_fault(struct pt_regs *ctx)
{
    struct page_fault_event event = {};
    __u64 pid_tgid = bpf_get_current_pid_tgid();
    
    event.pid = pid_tgid >> 32;
    event.tid = pid_tgid & 0xFFFFFFFF;
    event.address = PT_REGS_PARM1(ctx);
    event.ip = PT_REGS_IP(ctx);
    event.error_code = PT_REGS_PARM2(ctx);
    event.flags = 2; // Mark as kprobe source
    
    bpf_get_current_comm(&event.comm, sizeof(event.comm));
    
    bpf_perf_event_output(ctx, &events, BPF_F_CURRENT_CPU, 
                          &event, sizeof(event));
    
    return 0;
}

char LICENSE[] SEC("license") = "GPL";
