addi x1, x0, 2
addi x2, x0, 4
addi x4, x0, 3
addi x5, x0, 5
addi x3, x0, 0
mac x3, x1, x2
mac x3, x4, x5 
sw x3, 0(x0) 
ebreak