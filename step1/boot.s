BOOTSEG = 0x07c0                /* BIOS加载boot代码的原始段地址 */
.code16                         
.section .text                  /* 正文段*/
.globl _start                   /* 告知链接程序，程序从_start标号处开始执行*/
_start:
      ljmp $BOOTSEG, $go        /*  段间跳转。执行前所有寄存器值均为0，执行后cs=0x07c0*/
go:   
     	movw %cs, %ax                 
      movw %ax, %ds
      movw %ax, %es
      movb %ah, msg1+20         /* 响铃的ASCII值为07*/
      movw $22, %cx             /* 包括回车和换行共显示22个字符*/
      movw $0x1200,%dx          /* 显示在第19行，第1列*/	
      movw $0x0002,%bx       	  /* 颜色属性*/
      movw $msg1,%bp            /* 指向要显示的字符串*/	
      movw $0x1301,%ax       	  /* 中断功能0x13，子功能01*/
      int $0x10                

      movw $25, %cx 
      movw $0x1400,%dx
      movw $0x003f,%bx       	
      movw $msg2,%bp          	
      movw $0x1301,%ax         	
      int $0x10                
loop: jmp loop                  /* 死循环，此处应该开始加载内核代码*/
msg1:         .ascii " Loading system ... "
              .byte 13,10
msg2:         .ascii " Welcome to SongOS ^_^ "
              .byte 13,10        
.org 510                        /* 表示以后语句从地址510(0x1FE)开始存放*/
              .word 0xAA55      /* 有效引导扇区标志，供BIOS加载引导扇区使用，第510字节必须是0x55，第511字节必须是0xAA.*/ 
