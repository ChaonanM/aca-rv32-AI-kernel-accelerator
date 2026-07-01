addi x1, x0, 2        
addi x2, x0, 3        
mul x3, x1, x2        
mul x3, x3, x2        
mul x5, x3, x2        
sw x5, 0(x0)          
ebreak