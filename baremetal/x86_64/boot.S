/* Multiboot2 enters in 32-bit protected mode. Establish identity-mapped
   paging, enable long mode, then call the freestanding C kernel using the
   x86_64 System V ABI. This is the unavoidable architecture bootstrap; the
   OS contracts begin at ern_baremetal_main. */

.set MULTIBOOT2_HEADER_MAGIC, 0xE85250D6
.set MULTIBOOT2_ARCH_I386, 0
.set MULTIBOOT2_BOOT_MAGIC, 0x36D76289
.set CR0_PAGING, 0x80000000
.set CR4_PAE, 0x00000020
.set EFER_MSR, 0xC0000080
.set EFER_LONG_MODE, 0x00000100
.set PAGE_PRESENT_WRITE, 0x00000003
.set PAGE_PRESENT_WRITE_HUGE, 0x00000083
.set XEN_ELFNOTE_PHYS32_ENTRY, 18

.section .multiboot,"a"
.align 8
multiboot2_header:
    .long MULTIBOOT2_HEADER_MAGIC
    .long MULTIBOOT2_ARCH_I386
    .long multiboot2_header_end - multiboot2_header
    .long -(MULTIBOOT2_HEADER_MAGIC + MULTIBOOT2_ARCH_I386 + (multiboot2_header_end - multiboot2_header))
    .short 0
    .short 0
    .long 8
multiboot2_header_end:

/* QEMU's direct x86 -kernel loader follows the Xen PVH boot ABI. Keep a
   second standards-defined entry so local development does not require an
   ISO builder; GRUB still enters through _start and the Multiboot2 header. */
.section .note.Xen,"a",@note
.align 4
    .long 4
    .long 4
    .long XEN_ELFNOTE_PHYS32_ENTRY
    .asciz "Xen"
.align 4
    .long pvh_start
.align 4

.section .text.boot,"ax"
.code32
.global _start
.type _start, @function
_start:
    cli
    jmp boot_entry_common

.global pvh_start
.type pvh_start, @function
pvh_start:
    cli
    movl $MULTIBOOT2_BOOT_MAGIC, %eax

boot_entry_common:
    movl %eax, boot_magic
    movl %ebx, boot_information
    movl $boot_stack_top, %esp

    movl $page_table_l3, %eax
    orl $PAGE_PRESENT_WRITE, %eax
    movl %eax, page_table_l4

    movl $page_table_l2, %eax
    orl $PAGE_PRESENT_WRITE, %eax
    movl %eax, page_table_l3

    xorl %ecx, %ecx
1:
    movl %ecx, %eax
    shll $21, %eax
    orl $PAGE_PRESENT_WRITE_HUGE, %eax
    movl %eax, page_table_l2(,%ecx,8)
    movl $0, page_table_l2+4(,%ecx,8)
    incl %ecx
    cmpl $512, %ecx
    jne 1b

    movl $page_table_l4, %eax
    movl %eax, %cr3
    movl %cr4, %eax
    orl $CR4_PAE, %eax
    movl %eax, %cr4

    movl $EFER_MSR, %ecx
    rdmsr
    orl $EFER_LONG_MODE, %eax
    wrmsr

    movl %cr0, %eax
    orl $CR0_PAGING, %eax
    movl %eax, %cr0

    lgdt gdt_pointer
    .byte 0xEA
    .long long_mode_entry
    .word 0x08

.code64
long_mode_entry:
    movw $0x10, %ax
    movw %ax, %ds
    movw %ax, %es
    movw %ax, %ss
    xorw %ax, %ax
    movw %ax, %fs
    movw %ax, %gs
    movq $boot_stack_top, %rsp
    xorq %rbp, %rbp
    movl boot_magic(%rip), %edi
    movl boot_information(%rip), %esi
    call ern_baremetal_main

2:
    cli
    hlt
    jmp 2b
.size _start, . - _start

.align 8
gdt:
    .quad 0x0000000000000000
    .quad 0x00AF9A000000FFFF
    .quad 0x00CF92000000FFFF
gdt_end:
gdt_pointer:
    .word gdt_end - gdt - 1
    .long gdt

.section .bss,"aw",@nobits
.align 8
boot_magic:
    .long 0
boot_information:
    .long 0

.align 4096
page_table_l4:
    .skip 4096
page_table_l3:
    .skip 4096
page_table_l2:
    .skip 4096

.align 16
boot_stack_bottom:
    .skip 16384
boot_stack_top:

.section .note.GNU-stack,"",@progbits
