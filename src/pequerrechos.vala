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
 along with this program.  If not, see <http://www.gnu.org/licenses/>. */

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
		bool holidays[7];
		int time_used_today;
		int start_today;
		Gee.List<timelist> days;
		uint s_timer;
		bool today_is_holiday;
		int time_holidays;
		int time_no_holidays;
		string password;
		bool disabled;
		Indicator appindicator;
		string current_icon;

		public pequerrechos() {
			days=new Gee.ArrayList<timelist>();
			for(int i=1;i<6;i++) {
				this.holidays[i]=false;
			}
			this.holidays[0]=true; // sunday
			this.holidays[6]=true; // saturday
			this.time_used_today=0;
			this.start_today=-1;
			this.time_holidays=240;
			this.time_no_holidays=120;
			this.disabled=false;
			this.password="";
			var current_time=GLib.Time.local(time_t());
			this.today_is_holiday=holidays[current_time.weekday];
			this.appindicator = new Indicator("Pequerrechos","pequerrechos_lesstime",IndicatorCategory.APPLICATION_STATUS);
			this.current_icon="pequerrechos_lesstime";
			this.set_menu();
			string[] command={};
			command+="last";
			command+=Environment.get_user_name();
			this.launch_child(command,"/");
		}

		private int read_int(FileInputStream stream) {
			int val;
			uint8 buffer[4];
			try {
				stream.read(buffer);
				val=((int)(buffer[0]))+256*((int)(buffer[1]))+65536*((int)(buffer[2]))+16777216*((int)(buffer[3]));
			} catch (Error e) {
				val=0;
			}
			return val;
		}

		private string read_string(FileInputStream stream) {
			uint8 buffer[1];
			string retval="";
			try {
				do {
					stream.read(buffer);
					if (buffer[0]!=0) {
						retval+=((string)buffer);
					}
				} while (buffer[0]!=0);
			} catch (Error e) {
				retval="";
			}
			return retval;
		}

		public void read_configuration() {
			string home=Environment.get_home_dir();
			var config_file = File.new_for_path (GLib.Path.build_filename(home,".config/pequerrechos.cfg"));
			try {
				var filedata=config_file.read();
				int version;
				version=read_int(filedata);
				this.time_holidays=read_int(filedata);
				this.time_no_holidays=read_int(filedata);
				uint8 buffer[1];
				for(int v=0;v<7;v++) {
					filedata.read(buffer);
					if (buffer[0]==0) {
						this.holidays[v]=false;
					} else {
						this.holidays[v]=true;
					}
				}
				this.password=this.read_string(filedata);
			} catch (Error e) {
			}
		}

		private void write_int(FileOutputStream stream,int val) {
			int val2;
			uint8 buffer[4];
			val2=val;
			buffer[0]=(uint8)(val2%256);
			val2/=256;
			buffer[1]=(uint8)(val2%256);
			val2/=256;
			buffer[2]=(uint8)(val2%256);
			val2/=256;
			buffer[3]=(uint8)(val2%256);
			val2/=256;
			try {
				stream.write(buffer);
			} catch (Error e) {
			}
		}

		private void write_string(FileOutputStream stream, string str) {
			uint8 buffer[1];
			buffer[0]=0;
			try {
				stream.write(str.data);
				stream.write(buffer);
			} catch (Error e) {
			}
		}

		public void write_configuration() {
			string home=Environment.get_home_dir();
			var config_file = File.new_for_path (GLib.Path.build_filename(home,".config/pequerrechos.cfg"));
			try {
				if (config_file.query_exists()) {
					config_file.delete();
				}
				var filedata=config_file.append_to(FileCreateFlags.NONE);
				this.write_int(filedata,1); // version 1
				this.write_int(filedata,this.time_holidays);
				this.write_int(filedata,this.time_no_holidays);
				uint8 buffer[1];
				for(int l=0;l<7;l++) {
					if (this.holidays[l]) {
						buffer[0]=1;
					} else {
						buffer[0]=0;
					}
					filedata.write(buffer);
				}
				this.write_string(filedata,this.password);
			} catch (Error e) {
			}
		}

		public bool timer_func() {
			if(this.start_today!=-1) {
				var current_time=GLib.Time.local(time_t());
				int chour=current_time.hour*60+current_time.minute;
				if (chour<this.start_today) {
					chour+=1440; // 24 hours * 60 minutes/hour
				}
				if (this.disabled) {
					this.appindicator.set_icon_full("pequerrechos_disabled","Pequerrechos");
				} else {
					int time_left;
					int total_time;
					if (this.today_is_holiday) {
						total_time=this.time_holidays;
					} else {
						total_time=this.time_no_holidays;
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

			var menuBUnow = new Gtk.MenuItem.with_label(_("Back Up Now"));
			//menuBUnow.activate.connect(backup_now);
			menuSystem.append(menuBUnow);
			var menuSBUnow = new Gtk.MenuItem.with_label(_("Stop Backing Up"));
			//menuSBUnow.activate.connect(stop_backup);
			menuSystem.append(menuSBUnow);

			var menuEnter = new Gtk.MenuItem.with_label(_("Restore files"));
			//menuEnter.activate.connect(enter_clicked);
			menuSystem.append(menuEnter);

			var menuBar = new Gtk.SeparatorMenuItem();
			menuSystem.append(menuBar);

			var menuMain = new Gtk.MenuItem.with_label(_("Configure backup policies"));
			//menuMain.activate.connect(main_clicked);
			menuSystem.append(menuMain);

			menuSystem.show_all();
			this.appindicator.set_menu(menuSystem);

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
