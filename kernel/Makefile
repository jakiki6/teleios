all: kernel.bin
	for file in $^; do \
		echfs-utils ../os.img import $$file $$file; \
	done

%.bin: %.asm
	nasm -f bin -o $@ $<

clean:
	rm *.bin 2> /dev/null || true

.PHONY: all clean
