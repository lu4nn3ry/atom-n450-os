# Makefile for Intel Atom N450 Operating System (atom-n450-os)

CC ?= gcc
LD ?= ld
NASM ?= nasm

CFLAGS := -Wall -Wextra -O2 -ffreestanding -fno-stack-protector -fno-pie -mno-red-zone \
          -mno-mmx -mno-sse -mno-sse2 -mcmodel=large -Isrc/include
LDFLAGS := -n -T linker.ld -nostdlib -z max-page-size=0x1000

BUILD_DIR := build
BIN_DIR := bin
ISO_DIR := isodir

C_SRCS := $(wildcard src/kernel/*.c)
C_OBJS := $(patsubst src/kernel/%.c,$(BUILD_DIR)/%.o,$(C_SRCS))

ASM_SRCS := $(wildcard src/boot/*.asm)
ASM_OBJS := $(patsubst src/boot/%.asm,$(BUILD_DIR)/%.o,$(ASM_SRCS))

TARGET := $(BIN_DIR)/atom_kernel.elf
ISO_TARGET := $(BUILD_DIR)/atom_os.iso

.PHONY: all clean iso qemu

all: $(TARGET)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)
	mkdir -p $(BIN_DIR)

$(BUILD_DIR)/boot.o: src/boot/boot.asm | $(BUILD_DIR)
	$(NASM) -f elf64 $< -o $@

$(BUILD_DIR)/%.o: src/kernel/%.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(TARGET): $(BUILD_DIR)/boot.o $(C_OBJS) | $(BUILD_DIR)
	$(LD) $(LDFLAGS) -o $@ $^

iso: $(TARGET)
	mkdir -p $(ISO_DIR)/boot/grub
	cp $(TARGET) $(ISO_DIR)/boot/atom_kernel.elf
	echo 'set timeout=0' > $(ISO_DIR)/boot/grub/grub.cfg
	echo 'set default=0' >> $(ISO_DIR)/boot/grub/grub.cfg
	echo 'menuentry "Intel Atom N450 OS" {' >> $(ISO_DIR)/boot/grub/grub.cfg
	echo '    multiboot2 /boot/atom_kernel.elf' >> $(ISO_DIR)/boot/grub/grub.cfg
	echo '    boot' >> $(ISO_DIR)/boot/grub/grub.cfg
	echo '}' >> $(ISO_DIR)/boot/grub/grub.cfg
	grub-mkrescue -o $(ISO_TARGET) $(ISO_DIR) 2>/dev/null || echo "Para gerar ISO: instale grub-pc-bin e xorriso no Linux/WSL"

qemu: $(TARGET)
	qemu-system-x86_64 -kernel $(TARGET) -serial stdio -smp 2 -m 1024M

clean:
	rm -rf $(BUILD_DIR) $(BIN_DIR) $(ISO_DIR)
