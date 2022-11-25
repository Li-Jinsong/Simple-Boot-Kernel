AS  =as
LD  =ld
LDFLAGS =--oformat binary -Ttext 0x0

all:	Image

Image: boot system
	dd bs=512 if=boot of=Image
	dd bs=1 if=system of=Image seek=512
	sync

system:	head.s 
	$(AS) -o head.o head.s
	$(LD) $(LDFLAGS) -o system head.o

boot:	boot.s
	$(AS) -o boot.o boot.s
	$(LD) $(LDFLAGS) -o boot boot.o

clean:	
	rm -f Image core boot *.o system
