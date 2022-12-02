BOOTSEG = 0x07c0				
SYSSEG  = 0x1000				# 内核 head 先加载到 0x10000 处，然后移动到 0x0 处。
SYSLEN  = 17					# 内核占用的最大磁盘扇区数。
.code16                         
.section .text                  
.globl _start                   
_start:
	ljmp $BOOTSEG, $go        
go:								
	movw 	%cs, %ax
    movw 	%ax, %ds
    movw 	%ax, %es
    movb 	%ah, msg2+24         
    movw 	$26, %cx 
    movw	$0x1200,%dx         	
    movw 	$0x000b,%bx       	
    movw 	$msg2,%bp           	
    movw 	$0x1301,%ax       	
    int 	$0x10 
	movw 	$26, %cx 
    movw 	$0x1200,%dx
    movw 	$0x0000,%bx       	
    movw 	$msg3,%bp          	
    movw 	$0x1301,%ax 
	int 	$0x10

	movw 	$0x400,%sp			# 设置临时栈指针。其值需大于程序末端并有一定空间即可。（此处大于512即可）

load_system:					# 加载内核代码到内存 0x10000 开始处
	movw	$0x0000,%dx			# 如果从U盘启动，则为0x0080
	movw	$0x0002,%cx
	movw	$SYSSEG,%ax
	movw	%ax,%es
	movw	$0x0000,%bx
	movw	$0x200+SYSLEN,%ax
	int 	$0x13				# 从软盘的0磁头，0磁道，从第2个扇区起，连续读17个扇区到0x1000:0x0000（即0x10000）处。
	jnc		ok_load				# 若没有发生错误则跳转继续运行，否则死循环。
	movw	$0x0000,%dx			# 发生错误，重新初始化，开始循环
	movw	$0x0000,%ax
	int		$0x13
	jmp		load_system

ok_load: 						# 调用中断后，把内核代码移动到内存 0 开始处。
	cli							# 关中断
	movw 	$SYSSEG,%ax 		# 移动开始位置 DS:SI = 0x1000:0；目的位置 ES:DI=0:0。
	movw 	%ax,%ds
	xorw 	%ax,%ax
	movw 	%ax,%es
	movw 	$0x1000,%cx	    	# 设置cx表示共移动 4K 次。
	subw 	%si,%si
	subw 	%di,%di
	rep 
	movsw 						# 每次移动一个字
# 加载 IDT 和 GDT 基地址寄存器 IDTR 和 GDTR。							
	movw	$BOOTSEG,%ax		
	movw	%ax,%ds
	lidt 	idt_48 				# 加载IDTR（中断描述符表寄存器），其后面为一个内存地址；
								# 地址指向一个6字节的内存区域，前16位是IDT的界限值，后32位是IDT的线性地址。
	lgdt 	gdt_48				# 加载GDTR（全局描述符表寄存器）
	movw 	$0x0001,%ax 		# 在 CR0 中设置保护模式标志 PE。
	lmsw 	%ax 				
	ljmp 	$8,$0 				
# 下面是全局描述符表 GDT 的内容。其中包含 3 个段描述符。
# 段描述符用于向处理器提供有关一个段的位置、大小以及访问控制的状态信息。每个段描述符的长度是8个字节，含有3个主要字段：
# 段基地址，段属性，段限长
gdt: 
	.word 0,0,0,0 		# 段描述符 0，不用。每个描述符项占 8 字节。

	.word 0x07FF 		# 段描述符 1。8Mb - 段限长值=2047 (2048*4KB=8MB)。
	.word 0x0000 		# 段基地址=0x00000。
	.word 0x9A00 		# 是代码段，可读/执行。
	.word 0x00C0 		# 段属性颗粒度=4KB。

	.word 0x07FF 		# 段描述符 2。8Mb - 段限长值=2047 (2048*4KB=8MB)。
	.word 0x0000 		# 段基地址=0x00000。
	.word 0x9200 		# 是数据段，可读写。
	.word 0x00C0 		# 段属性颗粒度=4KB。
idt_48: .word 0 		# IDT 表长度是 0。
	.word 0,0 			# IDT 表的线性基地址也是 0。
gdt_48: .word 0x7ff 	# GDT 表长度是 2048 字节，可容纳 256 个描述符项。
	.word 0x7c00+gdt,0  # GDT 表的线性基地址在 0x7c0 段的偏移 gdt 处。
msg1:         .ascii " Loading system ... "
              .byte 13,10
msg2:         .ascii " Welcome to SongOS ^_^ ."
              .byte 13,10     
msg3:         .ascii "                        "
              .byte 13,10   
.org 510
.word 0xAA55
