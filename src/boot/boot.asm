; src/boot/boot.asm - Multiboot2 entry point & 64-bit Long Mode Transition
; Optimized for Intel Atom N450 (x86-64 / Bonnell)

global boot_entry
extern kmain

; ---------------------------------------------------------------------------
; Multiboot 2 Header
; ---------------------------------------------------------------------------
section .multiboot_header
align 8
mb2_header_start:
    dd 0xe85250d6                ; Magic number Multiboot 2
    dd 0                         ; Architecture 0 (i386 32-bit protected mode)
    dd mb2_header_end - mb2_header_start ; Header length
    dd 0x100000000 - (0xe85250d6 + 0 + (mb2_header_end - mb2_header_start)) ; Checksum

    ; Tag: End of tags
    align 8
    dw 0                         ; type 0 = end
    dw 0                         ; flags
    dd 8                         ; size = 8
mb2_header_end:

; ---------------------------------------------------------------------------
; 32-bit Protected Mode Bootstrap
; ---------------------------------------------------------------------------
section .boot_text
bits 32

boot_entry:
    ; Disable interrupts immediately
    cli
    cld

    ; Setup a temporary stack
    mov esp, boot_stack_top

    ; Save Multiboot2 magic and information pointer
    mov edi, eax                 ; EDI = Multiboot2 Magic (0x36d76289)
    mov esi, ebx                 ; ESI = Multiboot2 Info pointer

    ; 1. Check if CPUID is available
    pushfd
    pop eax
    mov ecx, eax
    xor eax, 1 << 21             ; Invert ID bit
    push eax
    popfd
    pushfd
    pop eax
    push ecx
    popfd
    cmp eax, ecx
    je .no_cpuid

    ; 2. Check for Long Mode (64-bit support) via CPUID
    mov eax, 0x80000000
    cpuid
    cmp eax, 0x80000001
    jb .no_long_mode

    mov eax, 0x80000001
    cpuid
    test edx, 1 << 29            ; LM bit in EDX
    jz .no_long_mode

    ; 3. Setup 4-level paging structures for Higher-Half transition
    ; Identity map first 2MB, and map higher-half 0xFFFFFFFF80000000 to first 2MB
    mov eax, boot_pdpt
    or eax, 0x03                 ; Present + Writable
    mov [boot_pml4], eax
    mov [boot_pml4 + 511 * 8], eax ; Higher-half entry (last entry of PML4)

    mov eax, boot_pd
    or eax, 0x03
    mov [boot_pdpt], eax
    mov [boot_pdpt + 510 * 8], eax ; Higher-half 2MB mapping

    ; Fill Page Directory with 2MB huge pages (Bit 7 = PS)
    mov ecx, 0
.map_pd:
    mov eax, 0x200000            ; 2MB size
    mul ecx
    or eax, 0x83                 ; Present + Writable + Huge (2MB)
    mov [boot_pd + ecx * 8], eax
    inc ecx
    cmp ecx, 4                   ; Map first 8MB
    jne .map_pd

    ; 4. Load CR3 with PML4 address
    mov eax, boot_pml4
    mov cr3, eax

    ; 5. Enable Physical Address Extension (PAE) in CR4
    mov eax, cr4
    or eax, 1 << 5               ; Bit 5 = PAE
    mov cr4, eax

    ; 6. Enable Long Mode in EFER MSR
    mov ecx, 0xC0000080          ; IA32_EFER MSR
    rdmsr
    or eax, 1 << 8               ; Bit 8 = LME (Long Mode Enable)
    wrmsr

    ; 7. Enable Paging (PG) and Protection (PE) in CR0
    mov eax, cr0
    or eax, (1 << 31) | (1 << 0) ; PG | PE
    mov cr0, eax

    ; 8. Load 64-bit Global Descriptor Table
    lgdt [gdt64_ptr]

    ; 9. Far jump into 64-bit Long Mode code segment
    jmp 0x08:long_mode_entry

.no_cpuid:
    mov al, 'C'
    jmp .error_halt

.no_long_mode:
    mov al, 'L'
    jmp .error_halt

.error_halt:
    ; Print error character to COM1 serial port (0x3F8)
    mov dx, 0x3F8
    out dx, al
.halt_loop:
    hlt
    jmp .halt_loop

; ---------------------------------------------------------------------------
; 64-bit Long Mode Entry Point
; ---------------------------------------------------------------------------
section .text
bits 64

long_mode_entry:
    ; Setup 64-bit data segment registers
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; Setup 64-bit stack in the higher-half
    mov rsp, kernel_stack_top

    ; Pass Multiboot parameters to kmain(uint64_t magic, uint64_t addr)
    mov rdi, rdi                 ; RDI = Multiboot2 magic
    mov rsi, rsi                 ; RSI = Multiboot2 pointer

    ; Jump to Kernel Main
    call kmain

    ; If kmain returns, halt CPU
.halt64:
    cli
    hlt
    jmp .halt64

; ---------------------------------------------------------------------------
; Data structures for booting
; ---------------------------------------------------------------------------
section .boot_data
align 16
gdt64:
    dq 0                         ; Null descriptor
    ; Kernel 64-bit Code Segment (0x08): DPL 0, Executable, Read/Write, 64-bit
    dq 0x00AF9A000000FFFF
    ; Kernel 64-bit Data Segment (0x10): DPL 0, Read/Write
    dq 0x00AF92000000FFFF
gdt64_end:

gdt64_ptr:
    dw gdt64_end - gdt64 - 1
    dq gdt64

section .boot_bss
align 4096
boot_pml4:
    resb 4096
boot_pdpt:
    resb 4096
boot_pd:
    resb 4096

boot_stack:
    resb 16384                   ; 16 KB boot stack
boot_stack_top:

section .bss
align 16
kernel_stack:
    resb 65536                   ; 64 KB kernel stack
kernel_stack_top:
