# Intel Atom N450 Operating System (atom-n450-os)

Um sistema operacional bare-metal de 64 bits (x86-64) construído especificamente para tirar proveito da arquitetura do processador **Intel Atom N450** (microarquitetura Bonnell / plataforma Pineview) e do chipset **Intel NM10 Express**.

---

## 🎯 Especificações Técnicas do Hardware Alvo

| Componente | Especificação | Detalhes no Sistema Operacional |
| :--- | :--- | :--- |
| **Processador** | Intel Atom N450 (Pineview-M) | 1 Core Físico / 2 Threads lógicas (Hyper-Threading / SMT) |
| **Pipeline** | Dual-Issue In-Order | Execução estrita em ordem de instruções; requer alinhamento e mitigação de stalls |
| **Instruções** | x86-64, MMX, SSE, SSE2, SSE3, SSSE3 | Suporte nativo a Long Mode (64 bits) e 64-bit paging |
| **Frequência & Cache** | 1.66 GHz / 512 KB L2 Cache | Pipeline de 16 estágios com pré-busca agressiva de dados |
| **Chipset** | Intel NM10 Express | Host Bridge, LPC, PCI, PCIe, SATA AHCI 1.0, USB 2.0 EHCI/UHCI |
| **Temporizadores** | HPET (High Precision Event Timer) + APIC Timer | Temporização de alta precisão para escalonamento preemptivo |
| **Gráficos** | Intel GMA 3150 Integrada | VBE Framebuffer / GOP (resolução nativa padrão de netbooks: 1024x600 32bpp) |
| **Áudio** | Intel High Definition Audio (HDA) | Controlador PCI 0x8086:0x27D8 com buffers circulares CORB/RIRB |
| **Armazenamento** | SATA II AHCI (0x8086:0x27C0 / 0x27C4) | DMA e PRDT nativos |

---

## 📋 TODO & Roadmap Interativo

O projeto acompanha um painel interativo de desenvolvimento em HTML que calcula o progresso dinamicamente e salva as tarefas concluídas no seu navegador:

👉 **Abra o arquivo [`TODO.html`](file:///D:/GitHub/atom-n450-os/TODO.html) no seu navegador para acompanhar ou marcar o progresso das tarefas!**

### Fases do Desenvolvimento:
1. **Toolchain & Bootloader**: Multiboot2, Long Mode (64 bits), Linker Higher-Half, saída Serial COM1 e ISO bootável.
2. **Núcleo de Arquitetura**: GDT64, TSS com IST, IDT (256 vetores), Local APIC & I/O APIC, HPET Timer.
3. **Gerenciamento de Memória**: PMM (Bitmap/Buddy Allocator), VMM (PML4 4 níveis), Page Fault Handler, kmalloc/kfree.
4. **Multithreading & Atom SMT**: Salva/restaura de contexto x86-64, inicialização de Thread 1 (Hyper-Threading AP) via INIT-SIPI-SIPI, alinhamento in-order de laços.
5. **Drivers do Intel NM10**: Scanner PCI, driver SATA AHCI, Teclado/Touchpad PS/2 (i8042), Framebuffer linear GMA 3150, Rede Realtek RTL8101E.
6. **Userland & Shell**: VFS (FAT32/Ext2), chamadas de sistema velozes `SYSCALL`/`SYSRET`, carregador ELF64 e terminal interativo Ring 3.

---

## 🛠️ Estrutura do Repositório

```text
atom-n450-os/
├── TODO.html          # Dashboard interativo com roadmap completo do projeto
├── README.md          # Documentação do processador e arquitetura
├── Makefile           # Script de compilação automatizada
├── linker.ld          # Script do linker x86-64 (Higher-Half)
└── src/
    ├── boot/          # Código de inicialização e transição de modo (Assembly)
    ├── kernel/        # Núcleo do sistema operacional (C/Assembly)
    └── include/       # Cabeçalhos do kernel e drivers de hardware
```

---

## 🚀 Como Testar no QEMU

Para testar o kernel em um ambiente emulado x86-64 com suporte a múltiplos núcleos (simulando as threads do Atom):

```bash
# Compilar imagem
make iso

# Executar no QEMU com saída serial no terminal
qemu-system-x86_64 -cdrom build/atom_os.iso -serial stdio -smp 2 -m 1024M
```
