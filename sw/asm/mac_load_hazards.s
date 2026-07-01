addi x2, x0, 4
addi x3, x0, 10
lw x1, 0(x0)
mac x3, x1, x2
addi x1, x0, 5
addi x4, x0, 1
lw x2, 4(x0)
mac x4, x1, x2
addi x1, x0, 2
addi x2, x0, 3
lw x5, 8(x0)
mac x5, x1, x2
add x6, x3, x4
add x6, x6, x5
sw x6, 0(x0)
ebreak
