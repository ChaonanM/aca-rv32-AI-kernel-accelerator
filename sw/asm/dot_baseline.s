addi x1, x0, 16       
addi x2, x0, 32       
addi x3, x0, 4        
addi x4, x0, 0        
loop: lw x5, 0(x1)    
lw x6, 0(x2)          
mul x7, x5, x6        
add x4, x4, x7        
addi x1, x1, 4        
addi x2, x2, 4        
addi x3, x3, -1       
bne x3, x0, loop      
sw x4, 0(x0)          
ebreak 