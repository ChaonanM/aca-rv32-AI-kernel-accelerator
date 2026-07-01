addi x1, x0, 2
addi x2, x0, 3
addi x3, x0, 1
mac x3, x1, x2
addi x4, x0, 7
bne x3, x4, fail
beq x0, x0, pass
mac x3, x1, x2
addi x31, x0, 1
fail: addi x31, x0, 2
pass: sw x3, 0(x0)
ebreak
