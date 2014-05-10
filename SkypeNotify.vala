namespace SkypeNotify {

	[DBus (name = "com.Skype.API")]
	public interface Skype : Object {
		public abstract string invoke(string request) throws IOError;
	}

	public errordomain SkypeOfflineError {
		OFFLINE
	}

	public class SkypeWrapper : Skype, Object {
		private Skype proxy;

		public SkypeWrapper(Skype proxy) throws IOError, SkypeOfflineError {
			this.proxy = proxy;

			stdout.printf("Registering with skype...\n");
			string nameResponse = invoke("NAME SkypeNotify");
			if (nameResponse == "CONNSTATUS OFFLINE") {
				throw new SkypeOfflineError.OFFLINE("Skype is offline");
			}
			check(nameResponse, "OK");
			check(invoke("PROTOCOL 7"), "PROTOCOL 7");
			stdout.printf("Registered with skype\n");
		}

		public string invoke(string request) throws IOError {
			return this.proxy.invoke(request);
		}

		private static void check(string response, string expectedResponse) throws IOError {
			if (response != expectedResponse) {
				throw new IOError.FAILED("Error calling Skype. Expected '%s' but got '%s'".printf(expectedResponse, response));
			}
		}
	}

	[DBus (name = "com.Skype.API.Client")]
	public class NotifyReceiver : Object {
		public new void notify(string notification) {
			// Forward skype notification to vala signal handlers
			this.notified(notification);
		}

		[DBus (visible = false)]
		public signal void notified (string notification);
	}

	private class NotifyHandler {
		private Mutex check_missed_chats_mutex = new Mutex();
		private string missed_chats_command;
		private string no_missed_chats_command;

		private SkypeWrapper skype;
		private NotifyReceiver notifyReceiver;

		public NotifyHandler(string missed_chats_command, string no_missed_chats_command) {
			this.missed_chats_command = missed_chats_command;
			this.no_missed_chats_command = no_missed_chats_command;
			Bus.own_name (BusType.SESSION, "com.nhinds.SkypeNotify", BusNameOwnerFlags.NONE,
				this.on_own_name, () => {}, () => stderr.printf ("Could not aquire name\n"));
		}

		private void notified(string notification) {
			stdout.printf("Notified: %s\n", notification);
		}

		private void handle_chatmessage(string notification) {
			if (notification.has_prefix("CHATMESSAGE")) {
				check_missed_chats();
			}
		}

		private bool check_missed_chats() {
			check_missed_chats_mutex.lock();
			try {
				if (this.skype == null) {
					stderr.printf ("Can't check for skype if skype isn't present\n");
					return false;
				}

				string missed_chats;
				try {
					missed_chats = this.skype.invoke("SEARCH MISSEDCHATS");
				} catch (IOError e) {
					stderr.printf ("Error checking for missed messages: %s\n", e.message);
					return true;
				}

				if (missed_chats.has_prefix("CHATS ")) {
					bool has_missed_chats = missed_chats.char_count() > "CHATS ".char_count();
					on_missed_chats(has_missed_chats);
				} else {
					stderr.printf ("Unexpected response to SEARCH MISSEDCHATS: %s\n", missed_chats);
				}
				return true;
			} finally {
				check_missed_chats_mutex.unlock();
			}
		}

		private void on_missed_chats(bool has_missed_chats) {
			stdout.printf("Missed Chats: %s\n", has_missed_chats ? "true" : "false");
			string command = has_missed_chats ? missed_chats_command : no_missed_chats_command;
			int return_code = Posix.system(command);
			if (return_code != 0) {
				stderr.printf ("Unexpected exit code %d executing '%s'\n", return_code, command);
			}
		}

		private void on_own_name(DBusConnection conn) {
			this.notifyReceiver = new NotifyReceiver();
			this.notifyReceiver.notified.connect(this.notified);
			this.notifyReceiver.notified.connect(this.handle_chatmessage);
			Timeout.add_seconds(10, this.check_missed_chats);
			try {
				conn.register_object("/com/Skype/Client", this.notifyReceiver);
				Bus.watch_name(BusType.SESSION, "com.Skype.API", BusNameWatcherFlags.NONE, on_skype_present, on_skype_absent);
			} catch (IOError e) {
				stderr.printf ("Could not register service: %s\n", e.message);
			}
		}

		private void on_skype_present() {
			stdout.printf("Skype present\n");
			try {
				this.skype = new SkypeWrapper(Bus.get_proxy_sync(BusType.SESSION, "com.Skype.API", "/com/Skype"));
				check_missed_chats();
			} catch (SkypeOfflineError e) {
				stdout.printf("Skype is offline, retrying in 1s\n");
				Timeout.add_seconds(1, () => {on_skype_present();return false;});
			} catch (IOError e) {
				stderr.printf("Could not connect to Skype: %s\n", e.message);
			}
		}

		private void on_skype_absent() {
			this.skype = null;
			stdout.printf("Skype absent\n");
		}
	}

	private static NotifyHandler handler;

	static void main(string[] args) {
		if (args.length != 3) {
			stdout.printf("Usage: %s <missed chats command> <no missed chats command>\n", args[0]);
			return;
		}
		string missed_chats_command = args[1];
		string no_missed_chats_command = args[2];
		handler = new NotifyHandler(missed_chats_command, no_missed_chats_command);

		new MainLoop().run();
	}
}
