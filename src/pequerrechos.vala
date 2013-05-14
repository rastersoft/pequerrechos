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
using Posix;

// project version=0.99.3

namespace pequerrechos {


	class pequerrechos : GLib.Object {
		private uint s_timer;
		private bool today_is_holiday;
		private Indicator appindicator;
		private string current_icon;
		private Gtk.MenuItem disable_for_today;
		private Gtk.MenuItem enable_again;
		private Gtk.MenuItem holiday_today;
		private Gtk.MenuItem not_holiday_today;
		private Gtk.MenuItem time_left_entry;
		private uint last_time_left;
		private show_timeout time_msg;
		private lock_w lock_window;
		private uint extra_time;
		private bool use_girl;

		private configuration config;

		bool lock_menu;

		public signal void updated_time(uint v);

		private int last_time;

		public pequerrechos() {
			int time_now=(int)(time_t());
			if((time_now%2)==0) {
				this.use_girl=false;
			} else {
				this.use_girl=true;
			}
			this.last_time_left=-1;
			this.extra_time=0;
			this.last_time=0;
			this.lock_menu=false;
			this.time_msg=new show_timeout();
			this.config=new configuration();
			this.lock_window=new lock_w(this.config);
			var current_time=GLib.Time.local(time_t());
			this.today_is_holiday=config.holidays[current_time.weekday];
			this.appindicator = new Indicator("Pequerrechos","",IndicatorCategory.APPLICATION_STATUS);
			this.appindicator.set_status(IndicatorStatus.ACTIVE);
			this.current_icon="";
			this.set_menu();
			if(this.today_is_holiday) {
				this.holiday_today.hide();
				this.not_holiday_today.show();
			} else {
				this.holiday_today.show();
				this.not_holiday_today.hide();
			}
		}

		private void set_icon(string icon) {
			if (this.current_icon!=icon) {
				string icon2;
				if (this.use_girl) {
					icon2=icon+"girl";
				} else {
					icon2=icon;
				}
				this.appindicator.set_icon_full(icon2,"Pequerrechos");
				GLib.stdout.printf("Icono: %s\n",icon2);
				this.current_icon=icon;
			}
		}

		private void set_time_left(uint time_left) {
			updated_time(time_left);
			if (time_left==this.last_time_left) {
				return;
			}
			this.last_time_left=time_left;
			uint hours;
			uint minutes;
			hours=time_left/60;
			minutes=time_left%60;
			this.time_left_entry.set_label(_("Time left: %02u:%02u").printf(hours,minutes));
		}

		public bool timer_func() {
			this.config.update_time(false);
			GLib.stdout.printf("Time used: %u\n",this.config.time_data);
			uint time_left;
			bool force=false;
			if (this.config.disabled) {
				if (this.current_icon!="pequerrechos_disabled") {
					this.set_icon("pequerrechos_disabled");
					this.disable_for_today.hide();
					this.enable_again.show();
				}
				time_left=-1;
			} else {
				if (this.current_icon=="pequerrechos_disabled") {
					this.disable_for_today.show();
					this.enable_again.hide();
				}
				uint total_time;
				if (this.today_is_holiday) {
					total_time=this.config.time_holidays+this.extra_time;
				} else {
					total_time=this.config.time_no_holidays+this.extra_time;
				}
				if(total_time>this.config.time_data) {
					time_left=total_time-this.config.time_data;
				} else {
					time_left=0;
				}
				if (this.config.extra_time!=0) {
					if (time_left==0) {
						this.extra_time+=this.config.extra_time+this.config.time_data-total_time;
					} else {
						this.extra_time+=this.config.extra_time;
					}
					this.config.extra_time=0;
					if (this.today_is_holiday) {
						total_time=this.config.time_holidays+this.extra_time;
					} else {
						total_time=this.config.time_no_holidays+this.extra_time;
					}
					if(total_time>this.config.time_data) {
						time_left=total_time-this.config.time_data;
					} else {
						time_left=0;
					}
				}
				set_time_left(time_left);
				if (time_left>10) {
					this.set_icon("pequerrechos_fine");
					this.last_time=0;
				} else if (time_left>5) {
					if (this.last_time!=10) {
						this.last_time=10;
						force=true;
					}
				} else if (time_left>2) {
					if (this.last_time!=5) {
						this.last_time=5;
						force=true;
					}
					this.set_icon("pequerrechos_lesstime");
				} else if (time_left>1) {
					if (this.last_time!=2) {
						this.last_time=2;
						force=true;
					}
				} else {
					if (this.last_time!=1) {
						this.last_time=1;
						force=true;
					}
					this.set_icon("pequerrechos_notime");
				}
			}
			if (time_left==0) {
				this.time_msg.do_hide();
				this.lock_window.show();
			} else {
				this.time_msg.change_text(time_left,force);
				this.lock_window.hide();
			}
			return true;
		}

		public void start() {
			s_timer=GLib.Timeout.add(1000,this.timer_func);
		}

		private void set_menu() {
			var menuSystem = new Gtk.Menu();
			var menuDate = new Gtk.MenuItem();

			menuDate.sensitive=false;
			menuSystem.append(menuDate);

			this.time_left_entry = new Gtk.MenuItem.with_label("");
			this.time_left_entry.sensitive=false;
			menuSystem.append(this.time_left_entry);

			var menuentry = new Gtk.MenuItem.with_label(_("Configure"));
			menuentry.activate.connect(configure);
			menuSystem.append(menuentry);

			this.holiday_today = new Gtk.MenuItem.with_label(_("Make today a holiday"));
			this.holiday_today.activate.connect(is_holiday_today);
			menuSystem.append(this.holiday_today);

			this.not_holiday_today = new Gtk.MenuItem.with_label(_("Make today not holiday"));
			this.not_holiday_today.activate.connect(is_not_holiday_today);
			menuSystem.append(this.not_holiday_today);

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
			GLib.stdout.printf("final\n");
		}

		public void configure() {
			if (this.lock_menu) {
				return;
			}
			this.lock_menu=true;
			var stg=new show_config(config);
			this.updated_time.connect(stg.update_time);
			stg.run();
			this.lock_menu=false;
		}

		public void disable_today() {
			if (this.lock_menu) {
				return;
			}
			this.lock_menu=true;
			var pwd=new ask_password();
			var retval=pwd.run(this.config.password);
			if (0==retval) {
				this.config.disabled=true;
			} else {
				if (retval!=1) {
					var msg=new show_message(_("Incorrect password"));
					msg=null;
				}
			}
			this.lock_menu=false;
		}

		public void enable_it_again() {
			if (this.lock_menu) {
				return;
			}
			this.lock_menu=true;
			var pwd=new ask_password();
			var retval=pwd.run(this.config.password);
			if (0==retval) {
				this.config.disabled=false;
			} else {
				if (retval!=1) {
					var msg=new show_message(_("Incorrect password"));
					msg=null;
				}
			}
			this.lock_menu=false;
		}

		public void is_holiday_today() {
			if (this.lock_menu) {
				return;
			}
			this.lock_menu=true;
			var pwd=new ask_password();
			var retval=pwd.run(this.config.password);
			if (0==retval) {
				this.today_is_holiday=true;
				this.holiday_today.hide();
				this.not_holiday_today.show();
			} else {
				if (retval!=1) {
					var msg=new show_message(_("Incorrect password"));
					msg=null;
				}
			}
			this.lock_menu=false;
		}

		public void is_not_holiday_today() {
			if (this.lock_menu) {
				return;
			}
			this.lock_menu=true;
			var pwd=new ask_password();
			var retval=pwd.run(this.config.password);
			if (0==retval) {
				this.today_is_holiday=true;
				this.holiday_today.show();
				this.not_holiday_today.hide();
			} else {
				if (retval!=1) {
					var msg=new show_message(_("Incorrect password"));
					msg=null;
				}
			}
			this.lock_menu=false;
		}
	}
}

int main(string[] args) {

	Posix.sleep(2); // to avoid problems when using autostart

	Intl.bindtextdomain(Constants.GETTEXT_PACKAGE, Path.build_filename(Constants.DATADIR,"locale"));
	Intl.setlocale (LocaleCategory.ALL, "");
	Intl.textdomain(Constants.GETTEXT_PACKAGE);
	Intl.bind_textdomain_codeset(Constants.GETTEXT_PACKAGE, "utf-8" );

	Gtk.init(ref args);
	var clase=new pequerrechos.pequerrechos();
	clase.start();
	Gtk.main();
	return 0;
}
