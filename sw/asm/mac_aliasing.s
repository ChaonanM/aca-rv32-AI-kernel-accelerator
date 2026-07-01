addi x2, x0, 3
addi x3, x0, 2
mac x3, x3, x2
mac x3, x2, x3
mac x3, x3, x3
sw x3, 0(x0)
ebreak
