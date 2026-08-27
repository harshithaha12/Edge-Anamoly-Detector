.include "buffer.asm"
.include "detect.asm"
.include "interrupt.asm"

.data



    .data

BUFFER_MEM:   .space 304          # 4 sensors x 76 bytes

NUM_TICKS:    .word 200
TICK_VALUES:  .word 0, 0, 0, 0

FILENAME:     .string "asm/sensor_data.txt"
FILE_FD:      .word 0
LINE_BUF:     .space 32
CHAR_BUF:     .space 1

STR_BOOT:     .string "Industrial Machine Monitoring System | RISC-V / RARS\n\n"
STR_DONE:     .string "\nSimulation complete\n"
STR_TICK:     .string "[PIPELINE] Tick "
STR_NL:       .string "\n"
STR_CLEAN:    .string "  [OK] All clear\n"
STR_ERR_FILE: .string "ERROR: could not open sensor_data.txt\nPlace it in the same folder as main.asm and rerun sensor_stream.py.\n"

    .text
    .globl main

main:
    la   a0, STR_BOOT
    li   a7, 4
    ecall

    # Patch BUFFER_BASE
    la   t0, BUFFER_MEM
    la   t1, BUFFER_BASE
    sw   t0, 0(t1)

    # Zero-init buffer headers
    li   s4, 0
init_loop:
    li   t0, 4
    bge  s4, t0, init_done
    mv   a0, s4
    jal  buf_base_addr
    sw   zero, 0(a0)
    sw   zero, 4(a0)
    sw   zero, 8(a0)
    addi s4, s4, 1
    j    init_loop
init_done:

    # Open sensor_data.txt  (ecall 1024 = Open in RARS)
    la   a0, FILENAME
    li   a1, 0               # flag 0 = read-only
    li   a7, 1024
    ecall                    # a0 = fd, or -1 on error

    bge  a0, zero, file_ok
    la   a0, STR_ERR_FILE
    li   a7, 4
    ecall
    li   a0, 1
    li   a7, 93              # Exit2 with code 1
    ecall

file_ok:
    la   t0, FILE_FD
    sw   a0, 0(t0)           # save fd

    li   s7, 1               # tick counter
    la   t0, NUM_TICKS
    lw   s6, 0(t0)           # total ticks

# MAIN PIPELINE LOOP

tick_loop:
    bgt  s7, s6, sim_done

    # STAGE 1 - FETCH: print tick number
    la   a0, STR_TICK
    li   a7, 4
    ecall
    mv   a0, s7
    li   a7, 1
    ecall
    la   a0, STR_NL
    li   a7, 4
    ecall

    # STAGE 2 - DECODE: read 4 integers from file, push to buffers
    li   s4, 0

read_loop:
    li   t0, 4
    bge  s4, t0, read_done

    # Read exactly one newline-terminated integer from the stream.
    jal  read_line_int
    bltz a0, sim_done

    # Save to TICK_VALUES[sensor]
    slli t0, s4, 2
    la   t1, TICK_VALUES
    add  t1, t1, t0
    sw   a0, 0(t1)

    # Push into ring buffer
    mv   a1, a0              # value
    mv   a0, s4              # sensor ID
    jal  buf_push

    addi s4, s4, 1
    j    read_loop
read_done:

    # STAGE 3 - EXECUTE: run detection on each sensor
    li   s4, 0
    li   s5, 0               # anomaly count this tick

detect_loop:
    li   t0, 4
    bge  s4, t0, detect_done

    mv   a0, s4
    jal  buf_peek_latest     # a0 = latest value
    mv   s3, a0

    mv   a0, s4
    mv   a1, s3
    jal  detect_all          # a0 = anomaly bitmask

    beqz a0, no_anomaly

    mv   a1, a0              # bitmask
    mv   a0, s4              # sensor ID
    mv   a2, s3              # value
    mv   a3, s7              # tick
    jal  raise_interrupt
    addi s5, s5, 1

no_anomaly:
    addi s4, s4, 1
    j    detect_loop

detect_done:
    bnez s5, next_tick
    la   a0, STR_CLEAN
    li   a7, 4
    ecall

next_tick:
    addi s7, s7, 1
    j    tick_loop

# SIMULATION COMPLETE

sim_done:
    # Close file  (ecall 57 = Close in RARS)
    la   t0, FILE_FD
    lw   a0, 0(t0)
    li   a7, 57
    ecall

    la   a0, STR_DONE
    li   a7, 4
    ecall

    jal  print_isr_stats

    li   a0, 0
    li   a7, 93              # Exit2
    ecall

# atoi - ASCII string to integer

atoi:
    li   t0, 0               # accumulator
    li   t2, 10              # multiplier
atoi_loop:
    lb   t1, 0(a0)           # load next byte
    beqz t1, atoi_done       # null terminator
    li   t3, 10
    beq  t1, t3, atoi_done   # newline (LF)
    li   t3, 13
    beq  t1, t3, atoi_done   # carriage return (CR)
    li   t3, 32
    beq  t1, t3, atoi_done   # space
    addi a0, a0, 1           # advance pointer
    li   t3, 48
    sub  t1, t1, t3          # ASCII digit -> integer
    mul  t0, t0, t2          # accumulator * 10
    add  t0, t0, t1          # add digit
    j    atoi_loop
atoi_done:
    mv   a0, t0
    ret

# read_line_int - Read one integer line from sensor_data.txt

read_line_int:
    addi sp, sp, -20
    sw   ra, 16(sp)
    sw   s0, 12(sp)
    sw   s1,  8(sp)
    sw   s2,  4(sp)
    sw   s3,  0(sp)

    la   s0, LINE_BUF        # write pointer
    li   s1, 0               # chars read into buffer
    li   s2, 31              # leave room for null terminator

read_line_loop:
    la   t0, FILE_FD
    lw   a0, 0(t0)
    la   a1, CHAR_BUF
    li   a2, 1
    li   a7, 63
    ecall

    blez a0, read_line_eof

    la   t0, CHAR_BUF
    lb   t1, 0(t0)

    li   t2, 13              # skip CR for Windows line endings
    beq  t1, t2, read_line_loop

    li   t2, 10              # LF terminates the line
    beq  t1, t2, read_line_done

    bge  s1, s2, read_line_loop
    sb   t1, 0(s0)
    addi s0, s0, 1
    addi s1, s1, 1
    j    read_line_loop

read_line_eof:
    beqz s1, read_line_fail

read_line_done:
    sb   zero, 0(s0)
    la   a0, LINE_BUF
    jal  atoi
    j    read_line_return

read_line_fail:
    li   a0, -1

read_line_return:
    lw   s3,  0(sp)
    lw   s2,  4(sp)
    lw   s1,  8(sp)
    lw   s0, 12(sp)
    lw   ra, 16(sp)
    addi sp, sp, 20
    ret
