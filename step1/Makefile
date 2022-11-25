# Makefile for the boot.
AS	=as
LD	=ld
 
all:	Image
 
Image:  boot
	dd bs=512 if=boot of=Image
	sync
 
boot:   boot.s
	$(AS) -o boot.o boot.s
	$(LD) --oformat binary -Ttext 0x0 -o boot boot.o
 
clean:
	rm -f  boot *.o