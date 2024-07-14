.section .data

welcome: .ascii  "\nCutom Bootloader\n\0"
iamhart: .ascii  "Booting HART \0"
newline: .ascii  "\n\0"

_hartlock:
    .skip 1,0

_scratchpad:
    .skip 1024,0


.section .text
.global _entry
_entry:
	# set up a stack for C.
    # stack0 is declared in start.c,
    # with a 4096-byte stack per CPU.
    # sp = stack0 + (hartid * 4096)
    la sp, stack0
    li a0, 1024*4
	csrr a1, mhartid
    addi a1, a1, 1
    mul a0, a0, a1
    add sp, sp, a0

    csrr t0, mhartid
    bnez t0, _announce

    # Setp UART + Print Welcome Message
    call _setup_uart
    la a0, welcome
    call _write_uart
    
    j _announce


_main_start:

    call start

# a0 should contain the address of a string to print
# writeln will then write this string to the UART device
# then newline gets printed
_writeln:
    mv s0, ra
    call _write_uart
    la a0, newline
    call _write_uart
    mv ra, s0
    ret

_setup_uart:
    # Disabling Interupts on the UART
    li t1, 0x10000001
    sb x0, 0(t1)
    # Write out to the UART Line Control Register at UART+3
    li t1, 0x10000003
    li t2, 0x03 # Set the output to 8 bits
    sb t2, 0(t1)
    ret

_write_uart:
    li t1, 0x10000005
_write_uart_wait:
    lb t2, 0(t1)
    li t3, 0x20
    and t2, t3, t1
    beqz t1, _write_uart_wait
    li t1, 0x10000000
_write_uart_send:
    lb t2, 0(a0)
    beqz t2, _write_uart_end
    sb t2, 0(t1)
    addi a0, a0, 1
    j _write_uart_send
_write_uart_end:
    ret

_announce:
    fence
    la t0, _hartlock
    lw t0, 0(t0)
    csrr t1, mhartid
    bne t0, t1, _announce

    # Write I am HART...
    la a0, iamhart
    call _write_uart

    # Add 0x30 to the HART ID to get ASCII Number
    csrr t1, mhartid
    li t2, 0x30
    add t1, t2, t1
    # Loading Scratchpad into a0
    la a0, _scratchpad
    # Store ASCII Hart ID into scratchpad
    sb t1, 0(a0)
    call _writeln

    # Increment the HART lock
    csrr t0, mhartid
    li t1, 0x01
    add t1, t0, t1
    la t2, _hartlock
    sw t1, 0(t2)

    la t0, _hartlock
    lw t1, 0(t0)

    fence

    j _main_start


spin:
    j spin
