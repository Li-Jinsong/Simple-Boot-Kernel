SCRN_SEL    = 0x18
TSS0_SEL    = 0x20
LDT0_SEL    = 0x28
TSS1_SEL    = 0X30
LDT1_SEL    = 0x38
.code32
.global startup_32
.text
startup_32:
    movl $0x10,%eax     # 0x10是数据段（在boot.s文件中定义）的选择子
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
    movl $397727, %eax      # timer frequency 3HZ 
    movl $0x40, %edx        # 端口是0x40
    outb %al, %dx           # 先写低字节
    movb %ah, %al           # 再写高字节
    outb %al, %dx

# 在新的位置重新设置 IDT 和 GDT 表。
    movl $0x00080000, %eax 
    movw $timer_interrupt, %ax  # 设置定时中断门描述符。取定时中断处理程序地址。
    movw $0x8E00, %dx           # 中断门类型是 14（屏蔽中断），特权级 0 或硬件使用。
    movl $0x08, %ecx            # 开机时 BIOS 设置的时钟中断向量号 8。这里直接使用
    lea idt(,%ecx,8), %esi      # 把 IDT 描述符 0x08 地址放入 ESI 中，然后设置该描述符。
    movl %eax,(%esi) 
    movl %edx,4(%esi)

    movw $system_interrupt, %ax # 设置系统调用陷阱门描述符。取系统调用处理程序地址。
    movw $0xef00, %dx           # 陷阱门类型是 15，特权级 3 的程序可执行。
    movl $0x80, %ecx            # 系统调用向量号是 0x80。
    lea idt(,%ecx,8), %esi      # 把 IDT 描述符项 0x80 地址放入 ESI 中，然后设置该描述符。
    movl %eax,(%esi) 
    movl %edx,4(%esi)

# 开始执行任务0，在堆栈中人工建立中断返回时的场景。
    pushfl
    andl $0xffffbfff, (%esp)
    popfl
    movl $TSS0_SEL, %eax
    ltr %ax
    movl $LDT0_SEL, %eax
    lldt %ax 
    movl $0, current            # 把当前任务号 0 保存在 current 变量中。
    sti                         # 现在开启中断，并在栈中营造中断返回时的场景。
    pushl $0x17
    pushl $init_stack
    pushfl
    pushl $0x0f
    pushl $task0
    iret

/**********GDT & IDT**********/	
# 使用 6 字节操作数 lgdt_opcode 设置 GDT 表位置和长度。
setup_gdt:
    lgdt lgdt_opcode
    ret
# 定义了一个长指针（段选择符：过程入口点偏移值），当发生中断的时候，处理器使用这个长指针把程序执行权转移到中断处理过程中。
# 把所有 256 个中断门描述符设置为使用默认处理过程。
setup_idt:
    lea ignore_int,%edx	    
    movl $0x00080000,%eax   
    movw %dx,%ax            
    movw $0x8E00,%dx        
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
# 显示字符子程序。取当前光标位置并把 AL 中的字符显示在屏幕上。
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
# ignore_int 是默认的中断处理程序，若系统产生了其他中断，则会在屏幕上显示一个字符'C'。
ignore_int:
    push %ds
    pushl %eax
    movl $0x10, %eax        # 首先让 DS 指向内核数据段，因为中断程序属于内核。
    mov %ax, %ds            
    movl $67, %eax          # 在 AL 中存放字符'C'
    call write_char         # 调用 write_char
    popl %eax
    pop %ds
    iret
.align 2
# 定时中断处理程序。主要执行任务切换操作。
timer_interrupt:
    push %ds
    pushl %eax
    movl $0x10, %eax        
    mov %ax, %ds
    movb $0x20, %al
    outb %al, $0x20         
    movl $1, %eax           
    cmpl %eax, current      # 判断当前任务，若是任务 1 则去执行任务 0，或反之。
    je 1f                   # 相等跳转到1处，切换到任务0
    movl %eax, current      
    ljmp $TSS1_SEL, $0      # 切换到任务1
    jmp 2f
1:  movl $0, current   
    ljmp $TSS0_SEL, $0
2:  popl %eax
    pop %ds
    iret
.align 2
# 系统调用中断 int 0x80 处理程序（显示字符）。
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
    .word 256*8-1       
    .long idt            
lgdt_opcode:
    .word (end_gdt-gdt)-1   
    .long gdt           

.align 8
idt:    .fill 256,8,0   # IDT 空间。共 256 个门描述符，每个 8 字节，占用 2KB。
gdt:
    # 各段描述符
    .quad 0x0000000000000000    
    .quad 0x00c09a00000007ff    
    .quad 0x00c09200000007ff    
    .quad 0x00c0920b80000002    
    .word 0x0068, tss0, 0xe900, 0x0
    .word 0x0040, ldt0, 0xe200, 0x0
    .word 0x0068, tss1, 0xe900, 0x0
    .word 0x0040, ldt1, 0xe200, 0x0
end_gdt:
	.fill 128,4,0       # 初始内核堆栈空间。
init_stack:             
    .long init_stack
    .word 0x10
/**********任务的LDT和TSS**********/
.align 8
ldt0:   
    .quad 0x0000000000000000
    .quad 0x00c0fa00000003ff    # 局部代码段描述符，对应选择符是 0x0f。
    .quad 0x00c0f200000003ff    # 局部数据段描述符，对应选择符是 0x17。
tss0:   
    .long 0     
    .long krn_stk0, 0x10       
    .long 0, 0, 0, 0, 0       
    .long 0, 0, 0, 0, 0  
    .long 0, 0, 0, 0, 0        
    .long 0, 0, 0, 0, 0, 0     
    .long LDT0_SEL, 0x8000000  

    .fill 128,4,0               # 这是任务 0 的内核栈空间。
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
    movl $0x17, %eax  # 0x17是任务0的数据段的选择子
    movw %ax, %ds    
	movb $2, %ah	  # 设置颜色
    movb $65, %al     # 'A' 
    int $0x80         # 系统调用，显示A
    movl $0xfff, %ecx # 执行循环，延时。
1:  loop 1b           
    jmp task0         
task1:
    movl $0x17, %eax  # 0x17是任务1的数据段的选择子
    movw %ax, %ds    
	movb $1,%ah       # 设置颜色
    movb $66, %al     # 'B' 
    int $0x80         # 系统调用，显示B
    movl $0xfff, %ecx # 执行循环，延时。
1:  loop 1b          
    jmp task1  

    .fill 128,4,0     # 任务1用户栈空间，每个 4 字节
usr_stk1:            
