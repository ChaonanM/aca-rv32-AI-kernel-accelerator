addi x1, x0, 2
addi x2, x0, 4
addi x4, x0, 10
sw x4, 0(x0)
lw x3, 0(x0)
mac x3, x1, x2
sw x3, 0(x0)
ebreak