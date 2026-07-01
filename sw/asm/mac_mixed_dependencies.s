addi x1, x0, -3
addi x2, x0, 7
mul x3, x1, x2
addi x4, x0, 5
mac x3, x4, x2
mul x5, x3, x2
mac x5, x1, x4
add x6, x5, x3
sw x6, 0(x0)
ebreak
