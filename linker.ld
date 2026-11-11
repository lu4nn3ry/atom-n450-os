/* linker.ld - Higher-Half x86_64 Linker Script for Intel Atom N450 OS */

ENTRY(boot_entry)

KERNEL_VMA = 0xFFFFFFFF80000000;
KERNEL_LMA = 0x0000000000100000;

SECTIONS
{
    . = KERNEL_LMA;

    /* Boot section executing at 1MB physical (32-bit entry before paging) */
    .boot ALIGN(4K) :
    {
        *(.multiboot_header)
        *(.boot_text)
        *(.boot_data)
        *(.boot_bss)
    }

    . += KERNEL_VMA;

    /* Higher-Half 64-bit kernel code */
    .text ALIGN(4K) : AT(ADDR(.text) - KERNEL_VMA)
    {
        *(.text*)
    }

    /* Read-only data */
    .rodata ALIGN(4K) : AT(ADDR(.rodata) - KERNEL_VMA)
    {
        *(.rodata*)
    }

    /* Read-write data */
    .data ALIGN(4K) : AT(ADDR(.data) - KERNEL_VMA)
    {
        *(.data*)
    }

    /* Uninitialized data */
    .bss ALIGN(4K) : AT(ADDR(.bss) - KERNEL_VMA)
    {
        *(COMMON)
        *(.bss*)
    }

    /DISCARD/ :
    {
        *(.comment)
        *(.eh_frame)
    }
}
