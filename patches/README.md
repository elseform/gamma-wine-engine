# Engine Patch Set

This document details the active patch set applied to CrossOver 26.3.0 / Wine 11.0 in `gamma-wine-engine`.

All patches are applied automatically in sequence by `scripts/build-wine.sh`.

---

## Active Patches in `gamma-wine-engine`

| # | Patch File | Subsystem | Purpose |
|---|---|---|---|
| 1 | `a6-final-same-view-backing-sync.patch` | `winemac.drv` | Synchronizes AppKit / Wine backing surfaces on macOS window resize/creation. |
| 2 | `wine-11.1-rtlwalkframechain-null-function.patch` | `ntdll` | Backport from Wine 11.1 to handle NULL functions safely during stack unwinding. |
| 3 | `cyder-ntdll-frame-walk-page-fault-guard.patch` | `ntdll` | Guards stack frame walking against page faults/crashes in 64-bit binaries. |
| 4 | `cyder-wineserver-sock-reselect-pseudo-fd.patch` | `wineserver` | Fixes wineserver socket pseudo-fd reselection during high-frequency poll calls. |
| 5 | `cyder-wineserver-poll-slot-guard.patch` | `wineserver` | Prevents poll table corruption when slots are released concurrently. |
| 6 | `cyder-wineserver-exit-diagnostics.patch` | `wineserver` | Adds clean diagnostic logging on process exit. |
| 7 | `cyder-wineserver-fd-reselect-async-null-ops.patch` | `wineserver` | Adds null check to async operations during fd reselection. |
| 8 | `cyder-wineserver-sock-rebind-async-fd.patch` | `wineserver` | Fixes socket rebinding race conditions in multithreaded networking. |
| 9 | `cyder-wineserver-async-terminate-null-fd.patch` | `wineserver` | Prevents null pointer dereference on async queue termination. |
| 10 | `cyder-wineserver-free-async-queue-null-fd.patch` | `wineserver` | Null pointer safety guard when freeing async queues. |
| 11 | `cyder-wineserver-pipe-end-disconnect-null-fd.patch` | `wineserver` | Fixes named pipe disconnect crash when fd is already closed. |
| 12 | `cyder-wineserver-add-completion-guard.patch` | `wineserver` | Prevents crash in I/O completion port notifications. |
| 13 | `cyder-ntdll-qdo-optnone-NtQueryDirectoryObject.patch` | `ntdll` | Disables aggressive Clang optimization on `NtQueryDirectoryObject` that caused miscompilation. |
| 14 | `gamma-ntdll-flush-write-buffers-sync.patch` | `ntdll` | Replaces expensive Mach thread register iteration in `NtFlushProcessWriteBuffers` with hardware memory barrier (`__sync_synchronize()`), preventing Rosetta 2 thread deadlocks. |

---

## Patches & Fixes That Resolved the Game Hanging

### 1. Reverted `maplestory-cx26-message-wait-handoff.patch` from `win32u.so`
- **The Problem**: A legacy patch modified `wait_message()` in `dlls/win32u/message.c` to skip `NtWaitForMultipleObjects` whenever `process_driver_events()` returned `TRUE`. On macOS, Cocoa mouse move and window events caused `wait_message()` to return immediately without blocking, resulting in an infinite CPU spinloop that deadlocked the main thread whenever any UI/menu element was clicked.
- **The Fix**: Completely reverted to standard upstream Wine implementation. Deleted the patch from `patches/` and `config/engine-release.json`.

### 2. Applied `gamma-ntdll-flush-write-buffers-sync.patch` to `ntdll.so`
- **The Problem**: CrossOver's macOS implementation of `NtFlushProcessWriteBuffers` in `dlls/ntdll/unix/virtual.c` called `task_threads()` and `thread_get_register_pointer_values()` on all Mach threads in the process to force memory synchronization. Under Rosetta 2 on Apple Silicon, querying translated x86 register state while worker threads yielded caused severe kernel thread stalls and hangs.
- **The Fix**: Replaced the Mach thread iteration loop with a hardware memory barrier (`__sync_synchronize()`), taking advantage of Apple Silicon's hardware Total Store Order (TSO) memory consistency.

---

## Dropped / Deleted Patches

All obsolete, unused, and game-specific hack patches have been removed from the repository:
- `patches/obsolete/*`: Deleted obsolete stack walk guard.
- `patches/cyder-ntdll-query-directory-object-trace.patch`: Deleted debug-only trace patch.
- `patches/w1-win32u-vulkan-soname.patch`: Deleted unused fallback patch.
- `patches/maplestory-cx26-*`: Deleted all ~20 game-specific hacks.
