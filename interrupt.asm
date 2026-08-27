    .data

STR_ALERT:     .string "[ALERT] Tick="
STR_SENSOR:    .string "  Sensor="
STR_TYPE:      .string "  Type="
STR_VALUE:     .string "  Value="
STR_DOT:       .string "."
STR_NEWLINE:   .string "\n"
STR_SEP:       .string "----------------------------------------\n"
STR_STATS_HDR: .string "\nTotal interrupts raised: "

# Sensor name lookup table  (4 pointers)
STR_TEMP:  .string "TEMPERATURE"
STR_VIB:   .string "VIBRATION"
STR_PRES:  .string "PRESSURE"
STR_HUM:   .string "HUMIDITY"

SENSOR_NAMES:
    .word STR_TEMP, STR_VIB, STR_PRES, STR_HUM

# Anomaly type strings (bitmask bits 0, 1, 2)
STR_TYPE_HI:    .string "THRESH_HIGH"
STR_TYPE_LO:    .string "THRESH_LOW"
STR_TYPE_DELTA: .string "RATE_OF_CHANGE"
STR_TYPE_MULTI: .string "MULTI"

ISR_COUNT: .word 0           # running total of interrupts raised

    .text

    .globl raise_interrupt
    .globl print_isr_stats

# raise_interrupt 

raise_interrupt:

    # Context save  (mirrors real RISC-V trap prologue)
    addi sp, sp, -48
    sw   ra,  44(sp)
    sw   s0,  40(sp)
    sw   s1,  36(sp)
    sw   s2,  32(sp)
    sw   s3,  28(sp)
    sw   t0,  24(sp)
    sw   t1,  20(sp)
    sw   t2,  16(sp)
    sw   a0,  12(sp)         # save args — ecall clobbers a0/a1/a7
    sw   a1,   8(sp)
    sw   a2,   4(sp)
    sw   a3,   0(sp)

    mv   s0, a0              # s0 = sensor ID
    mv   s1, a1              # s1 = bitmask
    mv   s2, a2              # s2 = raw value
    mv   s3, a3              # s3 = tick

    # increment ISR counter
    la   t0, ISR_COUNT
    lw   t1, 0(t0)
    addi t1, t1, 1
    sw   t1, 0(t0)

    # Print separator 
    la   a0, STR_SEP
    li   a7, 4
    ecall

    # "[ALERT] Tick=<n>" 
    la   a0, STR_ALERT
    li   a7, 4
    ecall

    mv   a0, s3
    li   a7, 1
    ecall

    # "  Sensor=<name>" 
    la   a0, STR_SENSOR
    li   a7, 4
    ecall

    slli t0, s0, 2
    la   t1, SENSOR_NAMES
    add  t1, t1, t0
    lw   a0, 0(t1)           # load pointer to sensor name string
    li   a7, 4
    ecall

    # "  Type=<anomaly>" 
    la   a0, STR_TYPE
    li   a7, 4
    ecall

    # Count set bits to detect MULTI condition
    li   t0, 0
    mv   t1, s1
count_bits:
    beqz t1, bits_done
    andi t2, t1, 1
    add  t0, t0, t2
    srli t1, t1, 1
    j    count_bits
bits_done:
    li   t3, 1
    bgt  t0, t3, print_multi

    andi t1, s1, 1
    bnez t1, print_hi
    andi t1, s1, 2
    bnez t1, print_lo
    j    print_delta_type

print_hi:
    la   a0, STR_TYPE_HI
    j    do_print_type
print_lo:
    la   a0, STR_TYPE_LO
    j    do_print_type
print_delta_type:
    la   a0, STR_TYPE_DELTA
    j    do_print_type
print_multi:
    la   a0, STR_TYPE_MULTI

do_print_type:
    li   a7, 4
    ecall

    # "  Value=<int>.<frac>" 
    
    la   a0, STR_VALUE
    li   a7, 4
    ecall

    li   t0, 100
    div  t1, s2, t0          # integer part  (RISC-V: single-instruction div)
    rem  t2, s2, t0          # fractional part (0-99)

    mv   a0, t1
    li   a7, 1
    ecall

    la   a0, STR_DOT
    li   a7, 4
    ecall

    # pad fractional with leading zero if < 10
    li   t3, 10
    bge  t2, t3, print_frac
    li   a0, '0'             # print leading '0'
    li   a7, 11              # ecall 11 = print character
    ecall

print_frac:
    mv   a0, t2
    li   a7, 1
    ecall

    la   a0, STR_NEWLINE
    li   a7, 4
    ecall

    # Context restore  
    lw   a3,   0(sp)
    lw   a2,   4(sp)
    lw   a1,   8(sp)
    lw   a0,  12(sp)
    lw   t2,  16(sp)
    lw   t1,  20(sp)
    lw   t0,  24(sp)
    lw   s3,  28(sp)
    lw   s2,  32(sp)
    lw   s1,  36(sp)
    lw   s0,  40(sp)
    lw   ra,  44(sp)
    addi sp, sp, 48

    ret                      

# print_isr_stats 
# Print total interrupts raised.  Call once at end of simulation.
print_isr_stats:
    addi sp, sp, -4
    sw   ra, 0(sp)

    la   a0, STR_SEP
    li   a7, 4
    ecall

    la   a0, STR_STATS_HDR
    li   a7, 4
    ecall

    la   t0, ISR_COUNT
    lw   a0, 0(t0)
    li   a7, 1
    ecall

    la   a0, STR_NEWLINE
    li   a7, 4
    ecall

    lw   ra, 0(sp)
    addi sp, sp, 4
    ret
