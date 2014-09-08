namespace HipChatNotify {
	[DBus (name = "org.kde.StatusNotifierWatcher")]
	public interface StatusNotifierWatcher : Object {
		public signal void status_notifier_item_registered(string item);
		public signal void status_notifier_item_unregistered(string item);
		public abstract string[] registered_status_notifier_items { owned get; }
	}

	[DBus (name = "org.kde.StatusNotifierItem")]
	public interface StatusNotifierItem : Object {
		public signal void new_status(string status);

		public abstract string id { owned get; }
		public abstract string status { owned get; }
	}

	static void main(string[] args) {
		// if (args.length != 3) {
		// 	stdout.printf("Usage: %s <missed chats command> <no missed chats command>\n", args[0]);
		// 	return;
		// }
		// string missed_chats_command = args[1];
		// string no_missed_chats_command = args[2];
		// handler = new NotifyHandler(missed_chats_command, no_missed_chats_command);
		StatusNotifierWatcher watcher;
		StatusNotifierItem hipchat;
		try {
			//FIXME no sync
			watcher = Bus.get_proxy_sync (BusType.SESSION, "org.kde.StatusNotifierWatcher", "/StatusNotifierWatcher");
			watcher.status_notifier_item_registered.connect( (item) => {
				stdout.printf ("I've got a jar of dirt! %s\n", item);
			});
			watcher.status_notifier_item_unregistered.connect( (item) => {
				stdout.printf ("I no longer have a jar of dirt :( %s\n", item);
			});
			foreach (string item in watcher.registered_status_notifier_items) {
				stdout.printf ("I started out with %s\n", item);
				int split = item.index_of_char('/');
				string service = item.substring(0, split);
				string name = item.substring(split);
				StatusNotifierItem notifier_item = Bus.get_proxy_sync(BusType.SESSION, service, name);
				string id = notifier_item.id;
				stdout.printf ("\t%s - %s\n", id, notifier_item.status);
				if (id == "HipChat") {
					stdout.printf ("Found hipchat at %s\n", item);
					hipchat = notifier_item;
					hipchat.new_status.connect( (status) => {
						stdout.printf ("New status: %s\n", status);
					});
				}
			}
		} catch (IOError e) {
			stderr.printf ("Error starting, blah: %s\n", e.message);
		}
		new MainLoop().run();
	}
}