BOOTSEG = 0x07c0                /* BIOS加载boot代码的原始段地址 */
.code16                         
.section .text                  /* 正文段*/
.globl _start                   /* 告知链接程序，程序从_start标号处开始执行*/
_start:
      ljmp $BOOTSEG, $go        /* 段间跳转。BOOTSEG指出跳转段地址，标号go是偏移地址,执行后cs=0x07C0*/
go:   
     	movw %cs, %ax
      movw %ax, %ds
      movw %ax, %es
      movb %ah, msg1+20         
      movw $22, %cx 
      movw $0x1200,%dx         	
      movw $0x0002,%bx       	
      movw $msg1,%bp           	
      movw $0x1301,%ax       	
      int $0x10                

      movw $25, %cx 
      movw $0x1400,%dx
      movw $0x003f,%bx       	
      movw $msg2,%bp          	
      movw $0x1301,%ax         	
      int $0x10                
loop: jmp loop                  /* 死循环 */
msg1:         .ascii " Loading system ... "
              .byte 13,10
msg2:         .ascii " Welcome to SongOS ^_^ "
              .byte 13,10        
.org 510                        /* 表示以后语句从地址510(0x1FE)开始存放*/
              .word 0xAA55      /*有效引导扇区标志，供BIOS加载引导扇区使用*/ 
