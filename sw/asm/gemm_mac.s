addi x1, x0, 64
addi x2, x0, 128
addi x3, x0, 0
addi x4, x0, 4
row_loop: addi x5, x0, 4
add x6, x2, x0
column_loop: add x7, x1, x0
add x8, x6, x0
addi x9, x0, 0
addi x10, x0, 4
inner_loop: lw x11, 0(x7)
lw x12, 0(x8)
mac x9, x11, x12
addi x7, x7, 4
addi x8, x8, 16
addi x10, x10, -1
bne x10, x0, inner_loop
sw x9, 0(x3)
addi x3, x3, 4
addi x6, x6, 4
addi x5, x5, -1
bne x5, x0, column_loop
addi x1, x1, 16
addi x4, x4, -1
bne x4, x0, row_loop
ebreak
