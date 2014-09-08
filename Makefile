PKGS = --pkg gio-2.0 --pkg posix
VALAC = valac

all: SkypeNotify HipChatNotify

SkypeNotify: SkypeNotify.vala
	$(VALAC) $(PKGS) -o SkypeNotify SkypeNotify.vala

HipChatNotify: HipChatNotify.vala
	$(VALAC) $(PKGS) -o HipChatNotify HipChatNotify.vala

clean:
	rm -f SkypeNotify HipChatNotify
