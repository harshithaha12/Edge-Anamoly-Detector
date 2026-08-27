    .data

# Per-sensor threshold tables (indexed by sensor ID × 4)

THRESH_HI:                   # upper bounds (scaled ×100)
    .word 9000               # sensor 0  temperature  > 90.00 °C
    .word  800               # sensor 1  vibration    >  8.00 g
    .word  600               # sensor 2  pressure     >  6.00 bar
    .word 8500               # sensor 3  humidity     > 85.00 %

THRESH_LO:                   # lower bounds (0 = disabled)
    .word    0               # sensor 0  no lower bound
    .word    0               # sensor 1  no lower bound
    .word   50               # sensor 2  pressure     <  0.50 bar
    .word    0               # sensor 3  no lower bound

THRESH_DELTA:                # max allowed change per tick (scaled ×100)
    .word 1500               # sensor 0  temperature  Δ > 15.00 °C
    .word  300               # sensor 1  vibration    Δ >  3.00 g
    .word  150               # sensor 2  pressure     Δ >  1.50 bar
    .word  700               # sensor 3  humidity     Δ >  7.00 %

# Previous values for delta calculation (one word per sensor, zeroed at start)

PREV_VALUES:
    .word 0, 0, 0, 0

# String labels used by interrupt.asm (defined here, referenced externally)

STR_THRESH_HI:  .string "THRESHOLD_HIGH"
STR_THRESH_LO:  .string "THRESHOLD_LOW"
STR_DELTA:      .string "RATE_OF_CHANGE"
STR_MULTI:      .string "MULTI"
STR_OK:         .string "OK"

    .text

    .globl detect_threshold
    .globl detect_delta
    .globl detect_all

# detect_threshold 

detect_threshold:
    mv   t2, a0              # preserve sensor ID before building return bitmask
    li   a0, 0               # start with clean bitmask
    slli t0, t2, 2           # byte offset into tables

    # upper threshold check
    la   t1, THRESH_HI
    add  t1, t1, t0
    lw   t1, 0(t1)           # t1 = THRESH_HI[sensor]
    ble  a1, t1, check_lo    # a1 = value passed in; still valid here
    ori  a0, a0, 1           # set bit 0

check_lo:
    la   t1, THRESH_LO
    add  t1, t1, t0
    lw   t1, 0(t1)
    beqz t1, thresh_done     # 0 = disabled
    bge  a1, t1, thresh_done
    ori  a0, a0, 2           # set bit 1

thresh_done:
    ret

# detect_delta

detect_delta:
    slli t0, a0, 2           # byte offset

    la   t1, PREV_VALUES
    add  t1, t1, t0
    lw   t1, 0(t1)           # t1 = previous value

    # The first sample establishes a baseline and should not trigger a delta alert.
    beqz t1, delta_seed

    # delta = abs(current - previous)
    sub  t2, a1, t1
    bgez t2, delta_pos
    neg  t2, t2              # abs
delta_pos:

    # store current as new previous
    la   t3, PREV_VALUES
    add  t3, t3, t0
    sw   a1, 0(t3)

    # compare against threshold
    la   t3, THRESH_DELTA
    add  t3, t3, t0
    lw   t3, 0(t3)

    li   a0, 0
    ble  t2, t3, delta_done
    li   a0, 1               # exceeded

delta_done:
    ret

delta_seed:
    la   t3, PREV_VALUES
    add  t3, t3, t0
    sw   a1, 0(t3)
    li   a0, 0
    ret

# detect_all 

detect_all:
    addi sp, sp, -24
    sw   ra, 20(sp)
    sw   s0, 16(sp)
    sw   s1, 12(sp)
    sw   s2,  8(sp)
    sw   s3,  4(sp)

    mv   s0, a0              # s0 = sensor ID
    mv   s1, a1              # s1 = value
    li   s2, 0               # s2 = accumulating bitmask

    # threshold check 
    
    mv   t2, s0              # t2 = sensor_id (leaf uses t2 internally)
    mv   a1, s1              # restore a1 (detect_threshold reads it)
    mv   a0, s0
    jal  detect_threshold    # a0 = threshold bitmask
    or   s2, s2, a0          # merge bits 0 and 1

    # delta check 
    mv   a0, s0
    mv   a1, s1
    jal  detect_delta        # a0 = 0 or 1
    beqz a0, detect_all_done
    ori  s2, s2, 4           # set bit 2

detect_all_done:
    mv   a0, s2              # return bitmask

    lw   s3,  4(sp)
    lw   s2,  8(sp)
    lw   s1, 12(sp)
    lw   s0, 16(sp)
    lw   ra, 20(sp)
    addi sp, sp, 24
    ret
