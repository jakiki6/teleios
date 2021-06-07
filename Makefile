all:
	make -C boot
	make -C kernel
	make -C progs

	qemu-system-x86_64 -hda os.img -enable-kvm -m 512M -D log.txt -d cpu_reset,int

clean:
	make -C boot clean
	make -C kernel clean
	make -C progs clean

	rm os.img log.txt 2> /dev/null || true

.PHONY: all clean
