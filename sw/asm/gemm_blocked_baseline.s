addi x1, x0, 64
addi x2, x0, 128
addi x3, x0, 0
addi x4, x0, 2
row_block_loop: addi x5, x0, 2
add x6, x2, x0
add x7, x3, x0
column_block_loop: addi x20, x0, 0
addi x21, x0, 0
addi x22, x0, 0
addi x23, x0, 0
add x8, x1, x0
addi x9, x1, 16
add x10, x6, x0
addi x11, x6, 4
addi x12, x0, 4
blocked_inner_loop: lw x13, 0(x8)
lw x14, 0(x9)
lw x15, 0(x10)
lw x16, 0(x11)
mul x17, x13, x15
add x20, x20, x17
mul x17, x13, x16
add x21, x21, x17
mul x17, x14, x15
add x22, x22, x17
mul x17, x14, x16
add x23, x23, x17
addi x8, x8, 4
addi x9, x9, 4
addi x10, x10, 16
addi x11, x11, 16
addi x12, x12, -1
bne x12, x0, blocked_inner_loop
sw x20, 0(x7)
sw x21, 4(x7)
sw x22, 16(x7)
sw x23, 20(x7)
addi x7, x7, 8
addi x6, x6, 8
addi x5, x5, -1
bne x5, x0, column_block_loop
addi x1, x1, 32
addi x3, x3, 32
addi x4, x4, -1
bne x4, x0, row_block_loop
ebreak
