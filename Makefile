AS=nasm
ASFLAGS=-f bin

# Build.
all: coma.com clean.com

coma.com: src/coma.asm
	$(AS) $(ASFLAGS) -o $@ $<

clean.com: src/clean.asm
	$(AS) $(ASFLAGS) -o $@ $<

# Test.
test: coma.com clean.com t/present.com t/toobig.com t/ok.com
	cp coma.com clean.com ./t
	SDL_VIDEODRIVER=dummy dosbox -conf dosbox/dosbox.conf -exit -c "cd t" "./t/test.bat"
	./t/test.sh
	@rm t/*.com t/*.COM t/*.TXT

t/present.com: t/present.asm
	$(AS) $(ASFLAGS) -o $@ $<

t/toobig.com: t/toobig.asm
	$(AS) $(ASFLAGS) -o $@ $<

t/ok.com: t/ok.asm
	$(AS) $(ASFLAGS) -o $@ $<

# Clean-up.
.PHONY: clean
clean:
	@rm coma.com clean.com
