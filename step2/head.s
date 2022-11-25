SCRN_SEL    = 0x18
TSS0_SEL    = 0x20
LDT0_SEL    = 0x28
TSS1_SEL    = 0X30
LDT1_SEL    = 0x38
.code32
.global startup_32
.text
startup_32:
    movl $0x10,%eax
    mov %ax,%ds
	lss init_stack,%esp

	call setup_idt
	call setup_gdt
	movl $0x10,%eax		    
	mov %ax,%ds		
	mov %ax,%es
	mov %ax,%fs
	mov %ax,%gs
	lss init_stack,%esp

# 设置定时芯片8253
    movb $0x36, %al         # al中是控制字
    movl $0x43, %edx        # 端口是0x43
    outb %al, %dx           # 把al中的控制字写入端口0x43
    movl $397727, %eax      # timer frequency 10 HZ 
    movl $0x40, %edx        # 端口是0x40
    outb %al, %dx           # 先写低字节
    movb %ah, %al           # 再写高字节
    outb %al, %dx

# 安装定时中断门描述符和系统调用陷阱门描述符
    movl $0x00080000, %eax 
    movw $timer_interrupt, %ax
    movw $0x8E00, %dx
    movl $0x08, %ecx        # The PC default timer int.
    lea idt(,%ecx,8), %esi
    movl %eax,(%esi) 
    movl %edx,4(%esi)

    movw $system_interrupt, %ax
    movw $0xef00, %dx
    movl $0x80, %ecx
    lea idt(,%ecx,8), %esi
    movl %eax,(%esi) 
    movl %edx,4(%esi)

# 开始执行任务0
    pushfl
    andl $0xffffbfff, (%esp)
    popfl
    movl $TSS0_SEL, %eax
    ltr %ax
    movl $LDT0_SEL, %eax
    lldt %ax 
    movl $0, current
    sti
    pushl $0x17
    pushl $init_stack
    pushfl
    pushl $0x0f
    pushl $task0
    iret
/**********GDT & IDT**********/	
setup_gdt:
    lgdt lgdt_opcode
    ret
setup_idt:
    lea ignore_int,%edx	    # 把ignore_int处的有效地址传给edx
    movl $0x00080000,%eax   #  段选择符（=0x08，索引1，内核代码段）组装完毕。
    movw %dx,%ax            # 过程入口点偏移值15-0组装完毕。
    movw $0x8E00,%dx        #  edx的低16位组装完毕
    lea idt,%edi
    mov $256,%ecx
rp_sidt:
    movl %eax,(%edi)
    movl %edx,4(%edi)
    addl $8,%edi
    dec %ecx
    jne rp_sidt
    lidt lidt_opcode
    ret
/**********打印字符程序**********/
write_char:
    push %gs
    pushl %ebx
    mov $SCRN_SEL, %ebx     # SCRN_SEL是显存段的选择子
    mov %bx, %gs            # gs指向显存段
    movl scr_loc, %ebx      # scr_loc处存放的是显示位置
    shl $1, %ebx            # ebx*2，得到偏移，因为一个字符用2个字节来描述
	# movb %al, %gs:(%ebx)  # ah是属性，al中是字符的ASCII码
    movw %ax, %gs:(%ebx)    # ah是属性，al中是字符的ASCII码
    shr $1, %ebx            # 还原ebx
    incl %ebx               # ebx自增1，算出下一个位置
    cmpl $2000, %ebx        # 比较ebx和2000
    jb 1f                   # 若 ebx < 2000 则跳转到1
    movl $0, %ebx           # 说明ebx==2000,因为位置只有0~1999，所以把ebx复位为0
1:  movl %ebx, scr_loc      # 把ebx存入scr_loc处，更新显示位置
    popl %ebx
    pop %gs
    ret
/**********三个中断处理程序**********/
.align 2
ignore_int:
    push %ds
    pushl %eax
    movl $0x10, %eax
    mov %ax, %ds            # 上一行和此行用内核数据段加载ds
    movl $67, %eax          # 打印字符'c'，实际上用AL来传参
    call write_char         # 调用过程 write_char
    popl %eax
    pop %ds
    iret
.align 2
timer_interrupt:
    push %ds
    pushl %eax
    movl $0x10, %eax        # 0x10是内核数据段的选择子
    mov %ax, %ds
    movb $0x20, %al
    outb %al, $0x20         # 向8259发送中断结束(EOI)命令，端口是0x20, 命令字是0x20,不用深究
    movl $1, %eax           # eax=1
    cmpl %eax, current
    je 1f                   # 相等跳转到1处，切换到任务0
    movl %eax, current      # current = 1
    ljmp $TSS1_SEL, $0      # 切换到任务1
    jmp 2f
1:  movl $0, current   
    ljmp $TSS0_SEL, $0
2:  popl %eax
    pop %ds
    iret
.align 2
system_interrupt:           # 0x80系统调用，把AL中的字符打印到屏幕上
    push %ds
    pushl %edx
    pushl %ecx
    pushl %ebx
    pushl %eax
    movl $0x10, %edx
    mov %dx, %ds        
    call write_char
    popl %eax
    popl %ebx
    popl %ecx
    popl %edx
    pop %ds
    iret
/******************************/
current:.long 0         # 当前任务号
scr_loc:.long 0         # 代码中留出了4字节存放位置

.align 2
lidt_opcode:
    .word 256*8-1       # idt contains 256 entries
    .long idt           # This will be rewrite by code. 
lgdt_opcode:
    .word (end_gdt-gdt)-1   
    .long gdt           # This will be rewrite by code.

.align 8
idt:    .fill 256,8,0   
gdt:
    .quad 0x0000000000000000    
    .quad 0x00c09a00000007ff    
    .quad 0x00c09200000007ff    
    .quad 0x00c0920b80000002    

    .word 0x0068, tss0, 0xe900, 0x0 # TSS0 descr 0x20
    .word 0x0040, ldt0, 0xe200, 0x0 # LDT0 descr 0x28
    .word 0x0068, tss1, 0xe900, 0x0 # TSS1 descr 0x30
    .word 0x0040, ldt1, 0xe200, 0x0 # LDT1 descr 0x38
end_gdt:
	.fill 128,4,0
init_stack:             
    .long init_stack
    .word 0x10
/**********任务的LDT和TSS**********/
.align 8
ldt0:   
    .quad 0x0000000000000000
    .quad 0x00c0fa00000003ff    # 0x0f
    .quad 0x00c0f200000003ff    # 0x17
tss0:   
    .long 0     
    .long krn_stk0, 0x10       
    .long 0, 0, 0, 0, 0       
    .long 0, 0, 0, 0, 0  
    .long 0, 0, 0, 0, 0        
    .long 0, 0, 0, 0, 0, 0     
    .long LDT0_SEL, 0x8000000  

    .fill 128,4,0
krn_stk0:
.align 8
ldt1:   
    .quad 0x0000000000000000
    .quad 0x00c0fa00000003ff   
    .quad 0x00c0f200000003ff   
tss1:   
    .long 0            
    .long krn_stk1, 0x10   
    .long 0, 0, 0, 0, 0   
    .long task1, 0x200     
    .long 0, 0, 0, 0       
    .long usr_stk1, 0, 0, 0   
    .long 0x17,0x0f,0x17,0x17,0x17,0x17 
    .long LDT1_SEL, 0x8000000   

    .fill 128,4,0
krn_stk1:
/**********任务的1和2的子程序**********/
task0:
    movl $0x17, %eax # 0x17是任务0的数据段的选择子
    movw %ax, %ds    # 因为任务0没有用到局部数据段，所以这两句可以不要
	movb $2, %ah	 # 设置颜色
    movb $65, %al    # print 'A' 
    int $0x80        # 系统调用
    movl $0xfff, %ecx
1:  loop 1b          # 为了延时
    jmp task0        # 死循环
task1:
    movl $0x17, %eax # 0x17是任务1的数据段的选择子
    movw %ax, %ds    # 因为任务1没有用到局部数据段，所以这两句可以不要
	movb $1,%ah
    movb $66, %al    # print 'B' 
    int $0x80        # 系统调用
    movl $0xfff, %ecx
1:  loop 1b          # 为了延时
    jmp task1        # 死循环
    .fill 128,4,0
usr_stk1:            # 任务1用户栈空间
