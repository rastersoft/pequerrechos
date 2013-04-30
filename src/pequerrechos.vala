/*
 Copyright 2013 (C) Raster Software Vigo (Sergio Costas)

 This file is part of Pequerrechos

 Pequerrechos is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 3 of the License, or
 (at your option) any later version.

 Pequerrechos is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

using GLib;
using Gtk;
using Gee;
using AppIndicator;

// project version=0.1

namespace pequerrechos {

	class timelist {
		public string month;
		public int day;
		public int duration;
		public int start;

		public timelist(int day, int start, int duration,string month) {
			this.day=day;
			this.start=start;
			this.duration=duration;
			this.month=month;
		}
	}

	class pequerrechos {
		private int time_used_today;
		private int start_today;
		private Gee.List<timelist> days;
		private uint s_timer;
		private bool today_is_holiday;
		private Indicator appindicator;
		private string current_icon;
		private Gtk.MenuItem disable_for_today;
		private Gtk.MenuItem enable_again;

		private configuration config;

		bool lock_menu;

		public pequerrechos() {
			this.lock_menu=false;
			this.config=new configuration();
			days=new Gee.ArrayList<timelist>();
			this.time_used_today=0;
			this.start_today=-1;
			var current_time=GLib.Time.local(time_t());
			this.today_is_holiday=config.holidays[current_time.weekday];
			this.appindicator = new Indicator("Pequerrechos","pequerrechos_lesstime",IndicatorCategory.APPLICATION_STATUS);
			this.current_icon="pequerrechos_lesstime";
			this.set_menu();
			string[] command={};
			command+="last";
			command+=Environment.get_user_name();
			this.launch_child(command,"/");
		}

		public bool timer_func() {
			if(this.start_today!=-1) {
				var current_time=GLib.Time.local(time_t());
				int chour=current_time.hour*60+current_time.minute;
				if (chour<this.start_today) {
					chour+=1440; // 24 hours * 60 minutes/hour
				}
				if (this.config.disabled) {
					if (this.current_icon!="pequerrechos_disabled") {
						this.appindicator.set_icon_full("pequerrechos_disabled","Pequerrechos");
						this.current_icon="pequerrechos_disabled";
						this.disable_for_today.hide();
						this.enable_again.show();
					}
				} else {
					if (this.current_icon=="pequerrechos_disabled") {
						this.disable_for_today.show();
						this.enable_again.hide();
					}
					int time_left;
					int total_time;
					if (this.today_is_holiday) {
						total_time=this.config.time_holidays;
					} else {
						total_time=this.config.time_no_holidays;
					}
					time_left=(total_time>chour) ? (total_time-chour) : 0;
					if (time_left>10) {
						if (this.current_icon!="pequerrechos_fine") {
							this.appindicator.set_icon_full("pequerrechos_fine","Time full");
							this.current_icon="pequerrechos_fine";
						}
					} else if (time_left>2) {
						if (this.current_icon!="pequerrechos_lesstime") {
							this.appindicator.set_icon_full("pequerrechos_lesstime","Time less");
							this.current_icon="pequerrechos_lesstime";
						}
					} else {
						if (this.current_icon!="pequerrechos_notime") {
							this.appindicator.set_icon_full("pequerrechos_notime","Time empty");
							this.current_icon="pequerrechos_notime";
						}
					}
				}
			}
			return true;
		}

		public void start() {
			s_timer=GLib.Timeout.add(1000,this.timer_func);
		}

		private void prepare_data() {
			int today=-1;
			string month="";
			int start=-1;
			foreach(var l in this.days) {
				if (l.duration==-1) { // this is "today"
					today=l.day;
					month=l.month;
					start=l.start;
					break;
				}
			}
			this.time_used_today=0;
			foreach(var l in this.days) {
				if ((l.day==today)&&(l.month==month)&&(l.duration!=-1)) {
					this.time_used_today+=l.duration;
				}
			}
			this.start_today=start;
			this.appindicator.set_status(IndicatorStatus.ACTIVE);
		}

		private bool process_line(IOChannel channel, IOCondition condition, string stream_name) {
			if (condition == IOCondition.HUP) {
				return false;
			}
			string line;
			try {
				channel.read_line (out line, null, null);
			} catch (IOChannelError e) {
				stdout.printf ("%s: IOChannelError: %s\n", stream_name, e.message);
				return false;
			} catch (ConvertError e) {
				stdout.printf ("%s: ConvertError: %s\n", stream_name, e.message);
				return false;
			}
			string[] parts=line.split(" ");
			string[] parts2={};
			foreach(var l in parts) {
				if ((l!="")&&(l!="\n")) {
					parts2+=l;
				}
			}
			// search the fields with session duration, start time and day
			string duration="";
			string start="";
			string day="";
			string month="";
			for(int l=parts2.length;l>0;l--) {
				var element=parts2[l-1];
				if (Regex.match_simple("^[0-9]([0-9])?$",element)) {
					day=element;
					month=parts2[l-2];
					break;
				}
				if (Regex.match_simple("^[0-9][0-9]:[0-9][0-9]$",element)) {
					start=element;
					continue;
				}
				if (Regex.match_simple("^\\([0-9][0-9]:[0-9][0-9]\\)$",element)) {
					duration=element.substring(1,5);
					continue;
				}
			}

			if ((day!="")&&(start!="")) {
				int duration_int;
				if (duration=="") {
					duration_int=-1;
				} else {
					duration_int=this.get_time(duration);
				}
				var element=new timelist(int.parse(day),this.get_time(start),duration_int,month);
				this.days.add(element);
			}
			return true;
		}

		private void set_menu() {
			var menuSystem = new Gtk.Menu();
			var menuDate = new Gtk.MenuItem();

			menuDate.sensitive=false;
			menuSystem.append(menuDate);

			var menuentry = new Gtk.MenuItem.with_label(_("Configure"));
			menuentry.activate.connect(configure);
			menuSystem.append(menuentry);

			menuentry = new Gtk.MenuItem.with_label(_("More time"));
			menuentry.activate.connect(more_time);
			menuSystem.append(menuentry);

			this.disable_for_today = new Gtk.MenuItem.with_label(_("Disable for today"));
			this.disable_for_today.activate.connect(disable_today);
			menuSystem.append(this.disable_for_today);

			this.enable_again = new Gtk.MenuItem.with_label(_("Enable again"));
			this.enable_again.activate.connect(enable_it_again);
			menuSystem.append(this.enable_again);

			menuSystem.show_all();
			this.disable_for_today.show();
			this.enable_again.hide();
			this.appindicator.set_menu(menuSystem);
		}

		public void configure() {
			if (this.lock_menu) {
				return;
			}
			this.lock_menu=true;
			var stg=new show_config(config);
			this.lock_menu=false;
		}

		public void more_time() {

		}

		public void disable_today() {
			if (this.lock_menu) {
				return;
			}
			this.lock_menu=true;
			var pwd=new ask_password();
			if (0==pwd.run(this.config.password)) {
				this.config.disabled=true;
			} else {
				var msg=new show_message(_("Incorrect password"));
				msg=null;
			}
			this.lock_menu=false;
		}

		public void enable_it_again() {
			if (this.lock_menu) {
				return;
			}
			this.lock_menu=true;
			var pwd=new ask_password();
			if (0==pwd.run(this.config.password)) {
				this.config.disabled=false;
			} else {
				var msg=new show_message(_("Incorrect password"));
				msg=null;
			}
			this.lock_menu=false;
		}

		private int get_time(string to_parse) {
			var elements=to_parse.split(":");
			var hours=int.parse(elements[0]);
			var minutes=int.parse(elements[1]);
			return (hours*60+minutes);
		}

		private bool launch_child(string[] parameters,string working_path) {
			string[] spawn_env = Environ.get ();
			Pid child_pid;

			int standard_input;
			int standard_output;
			int standard_error;

			try {
				Process.spawn_async_with_pipes (working_path,
					parameters,
					spawn_env,
					SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
					null,
					out child_pid,
					out standard_input,
					out standard_output,
					out standard_error);
			} catch(SpawnError e) {
				return true;
			}

			// stdout:
			IOChannel output = new IOChannel.unix_new (standard_output);
			output.add_watch (IOCondition.IN | IOCondition.HUP, (channel, condition) => {
				return process_line (channel, condition, "stdout");
			});

			// stderr:
			IOChannel error = new IOChannel.unix_new (standard_error);
			error.add_watch (IOCondition.IN | IOCondition.HUP, (channel, condition) => {
				return process_line (channel, condition, "stderr");
			});

			ChildWatch.add (child_pid, (pid, status) => {
				// Triggered when the child indicated by child_pid exits
				this.prepare_data();
				Process.close_pid (pid);
			});
			return false;
		}
	}
}

int main(string[] args) {
	Gtk.init(ref args);
	var clase=new pequerrechos.pequerrechos();
	clase.start();
	Gtk.main();
	return 0;
}
