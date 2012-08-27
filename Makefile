BUNDLE = artsyjumper.love
FILES = *.lua *.png sound design Makefile

love:
	zip -r $(BUNDLE) $(FILES)

