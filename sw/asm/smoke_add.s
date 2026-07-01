addi x1, x0, 2
addi x2, x0, 3
add x3, x1, x2
sub x4, x3, x1
mul x5, x1, x2
sw x3, 0(x0)
lw x6, 0(x0)
beq x6, x3, pass
addi x31, x0, 1
pass: bne x5, x0, end
addi x31, x0, 2
end: ebreak