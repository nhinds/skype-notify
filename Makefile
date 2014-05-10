PKGS = --pkg gio-2.0 --pkg posix
VALAC = valac

all: SkypeNotify

SkypeNotify: SkypeNotify.vala
	$(VALAC) $(PKGS) -o SkypeNotify SkypeNotify.vala

clean:
	rm -f SkypeNotify
