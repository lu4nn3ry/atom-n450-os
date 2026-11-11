#include "types.h"
#include "serial.h"

static void cpuid(uint32_t reg, uint32_t *eax, uint32_t *ebx, uint32_t *ecx, uint32_t *edx) {
    __asm__ volatile("cpuid"
        : "=a"(*eax), "=b"(*ebx), "=c"(*ecx), "=d"(*edx)
        : "a"(reg));
}

void print_banner(void) {
    serial_write_string("\n======================================================\n");
    serial_write_string("       Intel Atom N450 Operating System (64-bit)      \n");
    serial_write_string("  Target: Pineview / Bonnell Microarchitecture (x86-64)\n");
    serial_write_string("       Chipset: Intel NM10 Express / GMA 3150         \n");
    serial_write_string("======================================================\n\n");
}

void check_cpu(void) {
    uint32_t eax, ebx, ecx, edx;
    char vendor[13];

    // CPUID 0: Vendor String
    cpuid(0, &eax, (uint32_t*)(vendor), (uint32_t*)(vendor + 8), (uint32_t*)(vendor + 4));
    vendor[12] = '\0';

    serial_write_string("[CPU] Vendor: ");
    serial_write_string(vendor);
    serial_write_string("\n");

    // CPUID 1: Family, Model, Stepping
    cpuid(1, &eax, &ebx, &ecx, &edx);
    uint32_t stepping = eax & 0xF;
    uint32_t model = (eax >> 4) & 0xF;
    uint32_t family = (eax >> 8) & 0xF;
    uint32_t ext_model = (eax >> 16) & 0xF;

    uint32_t actual_model = (ext_model << 4) | model;

    serial_write_string("[CPU] Family: ");
    serial_write_hex(family);
    serial_write_string(" | Model: ");
    serial_write_hex(actual_model);
    serial_write_string(" | Stepping: ");
    serial_write_hex(stepping);
    serial_write_string("\n");

    if (family == 6 && actual_model == 28) {
        serial_write_string("[CPU] Detected Intel Atom Pineview (N450/D410/D510)!\n");
    } else {
        serial_write_string("[CPU] Note: Running on compatible x86-64 processor / QEMU.\n");
    }

    // Check Features: SMT (Hyper-Threading)
    if (edx & (1 << 28)) {
        uint32_t logical_cores = (ebx >> 16) & 0xFF;
        serial_write_string("[CPU] Hyper-Threading (SMT) Supported. Logical Threads: ");
        serial_write_hex(logical_cores);
        serial_write_string("\n");
    }

    // Check SSSE3
    if (ecx & (1 << 9)) {
        serial_write_string("[CPU] SSSE3 Instruction Set Supported.\n");
    }
}

void kmain(uint64_t magic, uint64_t mb2_info) {
    // 1. Initialize Serial Port for COM1 debug
    serial_init();

    // 2. Print Operating System Header
    print_banner();

    serial_write_string("[BOOT] Multiboot2 Magic: ");
    serial_write_hex(magic);
    serial_write_string("\n[BOOT] Multiboot2 Info Addr: ");
    serial_write_hex(mb2_info);
    serial_write_string("\n\n");

    // 3. Inspect CPUID & Features
    check_cpu();

    serial_write_string("\n[KERNEL] System initialized in 64-bit Long Mode.\n");
    serial_write_string("[KERNEL] Awaiting next subsystem bringup (GDT/IDT/PMM)...\n");

    // Halt loop
    while (1) {
        __asm__ volatile ("hlt");
    }
}
