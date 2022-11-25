BOOTSEG = 0x07c0				# 引导扇区（本程序）被 BIOS 加载到内存 0x7c00 处。不分配内
SYSSEG  = 0x1000				# 内核 head 先加载到 0x10000 处，然后移动到 0x0 处。
SYSLEN  = 17					# 内核占用的最大磁盘扇区数。
.code16                         
.section .text                  
.globl _start                   
_start:
	ljmp $BOOTSEG, $go        
go:								# 当本程序刚运行时所有段寄存器值均为 0。
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
	movw	$0x0000,%dx			
	movw	$0x0002,%cx
	movw	$SYSSEG,%ax
	movw	%ax,%es
	movw	$0x0000,%bx
	movw	$0x200+SYSLEN,%ax
	int 	$0x13				# 利用 BIOS 中断 int 0x13 功能 2 从启动盘读取 head 代码。
	jnc		ok_load				# 若没有发生错误则跳转继续运行，否则死循环。
	movw	$0x0000,%dx			# 重新初始化，开始循环
	movw	$0x0000,%ax
	int		$0x13
	jmp		load_system

ok_load: 						# 调用中断后，把内核代码移动到内存 0 开始处。共移动 8KB 字节（内核长度不超过 8KB）。
	cli							# 关中断
	movw 	$SYSSEG,%ax 		# 移动开始位置 DS:SI = 0x1000:0；目的位置 ES:DI=0:0。
	movw 	%ax,%ds
	xorw 	%ax,%ax
	movw 	%ax,%es
	movw 	$0x1000,%cx	    	# 设置cx表示共移动 4K 次，每次移动一个字（word）。
	subw 	%si,%si
	subw 	%di,%di
	rep 
	movsw 					# 重复移动
# 加载 IDT 和 GDT 基地址寄存器 IDTR 和 GDTR。							
	movw	$BOOTSEG,%ax		
	movw	%ax,%ds
	lidt 	idt_48 		
	lgdt 	gdt_48
# 设置控制寄存器 CR0（即机器状态字），进入保护模式。段选择符值 8 对应 GDT 表中第 2 个段描述符。
	movw 	$0x0001,%ax 		# 在 CR0 中设置保护模式标志 PE（位 0）。
	lmsw 	%ax 				# 然后跳转至段选择符值指定的段中，偏移 0 处。
	ljmp 	$8,$0 				# 注意此时段值已是段选择符。该段的线性基地址是 0。

# 下面是全局描述符表 GDT 的内容。其中包含 3 个段描述符。第 1 个不用，另 2 个是代码和数据段描述符。
gdt: 
	.word 0,0,0,0 		# 段描述符 0，不用。每个描述符项占 8 字节。

	.word 0x07FF 		# 段描述符 1。8Mb - 段限长值=2047 (2048*4096=8MB)。
	.word 0x0000 		# 段基地址=0x00000。
	.word 0x9A00 		# 是代码段，可读/执行。
	.word 0x00C0 		# 段属性颗粒度=4KB。

	.word 0x07FF 		# 段描述符 2。8Mb - 段限长值=2047 (2048*4096=8MB)。
	.word 0x0000 		# 段基地址=0x00000。
	.word 0x9200 		# 是数据段，可读写。
	.word 0x00C0 		# 段属性颗粒度=4KB。

# 下面分别是 LIDT 和 LGDT 指令的 6 字节操作数。
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
.word 0xAA55 			# 引导扇区有效标志。必须处于引导扇区最后 2 字节处。
