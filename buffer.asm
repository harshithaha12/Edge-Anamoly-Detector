    .data

    .globl BUFFER_BASE
    .globl BUF_SIZE
    .globl BUF_BLOCK

BUFFER_BASE: .word 0
BUF_SIZE:    .word 16
BUF_BLOCK:   .word 76

    .text

    .globl buf_base_addr
    .globl buf_push
    .globl buf_pop
    .globl buf_peek_latest

# buf_base_addr
# Compute start address of a sensor's buffer block.
# In:  a0 = sensor ID
# Out: a0 = block base address   
# Trashes: t0, t1
buf_base_addr:
    la   t0, BUF_BLOCK
    lw   t0, 0(t0)           # t0 = block size (76)
    mul  t1, a0, t0          # t1 = sensor_id * 76
    la   t0, BUFFER_BASE
    lw   t0, 0(t0)           # t0 = base address
    add  a0, t0, t1          # a0 = base + offset
    ret

# buf_push 
# Push one sample into the ring buffer.
# If full, oldest entry is silently overwritten (sliding-window behaviour).
# In:  a0 = sensor ID,  a1 = sample value (integer, scaled ×100)
# Out: nothing
# Trashes: t0–t4
buf_push:
    addi sp, sp, -16
    sw   ra,  12(sp)
    sw   s0,   8(sp)
    sw   s1,   4(sp)
    sw   s2,   0(sp)

    mv   s0, a0              # s0 = sensor ID
    mv   s1, a1              # s1 = value to push

    jal  buf_base_addr       # a0 = block address
    mv   t0, a0              # t0 = block address

    lw   t1,  0(t0)          # t1 = head index
    lw   t2,  8(t0)          # t2 = count

    # write address = block + 12 + head*4
    slli t3, t1, 2           # head * 4
    addi t3, t3, 12          # skip 3 header words
    add  t3, t0, t3          # absolute address
    sw   s1, 0(t3)           # store sample

    # head = (head + 1) % BUF_SIZE
    la   t4, BUF_SIZE
    lw   t4, 0(t4)
    addi t1, t1, 1
    rem  t1, t1, t4          # RISC-V: rem is a single instruction
    sw   t1, 0(t0)           # store updated head

    # count = min(count + 1, BUF_SIZE)
    addi t2, t2, 1
    la   t4, BUF_SIZE
    lw   t4, 0(t4)
    blt  t2, t4, push_store  # if count < BUF_SIZE, no clamp needed
    beq  t2, t4, push_store
    mv   t2, t4              # clamp

    # Buffer full: advance tail so the newest sliding window is preserved.
    lw   t3, 4(t0)
    addi t3, t3, 1
    rem  t3, t3, t4
    sw   t3, 4(t0)
push_store:
    sw   t2, 8(t0)

    lw   s2,   0(sp)
    lw   s1,   4(sp)
    lw   s0,   8(sp)
    lw   ra,  12(sp)
    addi sp, sp, 16
    ret

# buf_pop 
# Pop the oldest sample (FIFO order).

buf_pop:
    addi sp, sp, -8
    sw   ra, 4(sp)
    sw   s0, 0(sp)

    mv   s0, a0
    jal  buf_base_addr
    mv   t0, a0              # t0 = block address

    lw   t2, 8(t0)           # count
    beqz t2, pop_empty

    lw   t1, 4(t0)           # tail index
    slli t3, t1, 2
    addi t3, t3, 12
    add  t3, t0, t3
    lw   a0, 0(t3)           # read sample into return register

    # tail = (tail + 1) % BUF_SIZE
    la   t4, BUF_SIZE
    lw   t4, 0(t4)
    addi t1, t1, 1
    rem  t1, t1, t4
    sw   t1, 4(t0)

    addi t2, t2, -1
    sw   t2, 8(t0)
    j    pop_done

pop_empty:
    li   a0, -1              # sentinel: empty

pop_done:
    lw   s0, 0(sp)
    lw   ra, 4(sp)
    addi sp, sp, 8
    ret

# buf_peek_latest 
# Read the most recently pushed sample WITHOUT consuming it.
# Used by the detection pipeline to inspect current value each tick.

buf_peek_latest:
    addi sp, sp, -8
    sw   ra, 4(sp)
    sw   s0, 0(sp)

    mv   s0, a0
    jal  buf_base_addr
    mv   t0, a0

    lw   t2, 8(t0)           # count
    beqz t2, peek_empty

    lw   t1, 0(t0)           # head (next write slot)
    la   t4, BUF_SIZE
    lw   t4, 0(t4)
    addi t1, t1, -1
    add  t1, t1, t4
    rem  t1, t1, t4          # (head - 1 + N) mod N = last written slot

    slli t3, t1, 2
    addi t3, t3, 12
    add  t3, t0, t3
    lw   a0, 0(t3)
    j    peek_done

peek_empty:
    li   a0, -1

peek_done:
    lw   s0, 0(sp)
    lw   ra, 4(sp)
    addi sp, sp, 8
    ret
