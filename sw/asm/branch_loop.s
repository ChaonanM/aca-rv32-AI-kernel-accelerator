addi x1, x0, 0        
addi x2, x0, 1        
addi x3, x0, 6        
loop: add x1, x1, x2  
addi x2, x2, 1        
blt x2, x3, loop      
sw x1, 0(x0)          
ebreak