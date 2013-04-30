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

using Gtk;
using GLib;

namespace pequerrechos {

	public class ask_password: Object {

		private Gtk.Dialog main_w;
		private Gtk.Builder builder;
		private Gtk.Entry entry;

		public ask_password() {
			this.builder = new Builder();
			this.builder.add_from_file(GLib.Path.build_filename(Constants.PKGDATADIR,"ask_password.ui"));
			this.main_w = (Gtk.Dialog) this.builder.get_object("dialog1");
			this.entry = (Gtk.Entry) this.builder.get_object("password");
		}

		public void show() {
			this.main_w.present();
		}

		// returns 0 if the right password has been inserted;
		// returns -1 if the password was incorrect;
		// returns 1 if the user cancelled
		public int run(string pass) {
			this.main_w.show();
			var retval=this.main_w.run();
			Checksum checksum = new Checksum (ChecksumType.MD5);
			var text=this.entry.get_text();
			checksum.update(text.data,text.length);
			this.main_w.hide();
			this.main_w.destroy();
			if (retval!=1) {
				return 1;
			}
			if (pass==checksum.get_string ()) {
				return 0;
			} else {
				return -1;
			}
		}
	}

	public class show_message:Object {

		public show_message(string msg) {
			var builder = new Builder();
			builder.add_from_file(GLib.Path.build_filename(Constants.PKGDATADIR,"popup_message.ui"));
			var main_w = (Gtk.Dialog) builder.get_object("dialog1");
			var text = (Gtk.Label) builder.get_object("text");
			text.set_text(msg);
			main_w.show();
			main_w.run();
			main_w.hide();
			main_w.destroy();
		}
	}

	public class show_config:Object {

		private configuration config;
		private Builder builder;
		private Gtk.Adjustment time_holidays;
		private Gtk.Adjustment time_no_holidays;
		private Gtk.CheckButton sunday;
		private Gtk.CheckButton monday;
		private Gtk.CheckButton tuesday;
		private Gtk.CheckButton wednesday;
		private Gtk.CheckButton thursday;
		private Gtk.CheckButton friday;
		private Gtk.CheckButton saturday;
		private Gtk.Entry pass1;
		private Gtk.Entry pass2;

		public show_config(configuration config) {
			this.config=config;
			this.builder = new Builder();
			builder.add_from_file(GLib.Path.build_filename(Constants.PKGDATADIR,"settings.ui"));
			var main_w = (Gtk.Dialog) builder.get_object("settings");
			this.time_holidays=(Gtk.Adjustment)this.builder.get_object("time_holidays");
			this.time_no_holidays=(Gtk.Adjustment)this.builder.get_object("time_noholidays");
			this.sunday=(Gtk.CheckButton)this.builder.get_object("sunday");
			this.monday=(Gtk.CheckButton)this.builder.get_object("monday");
			this.tuesday=(Gtk.CheckButton)this.builder.get_object("tuesday");
			this.wednesday=(Gtk.CheckButton)this.builder.get_object("wednesday");
			this.thursday=(Gtk.CheckButton)this.builder.get_object("thursday");
			this.friday=(Gtk.CheckButton)this.builder.get_object("friday");
			this.saturday=(Gtk.CheckButton)this.builder.get_object("saturday");
			this.pass1=(Gtk.Entry)this.builder.get_object("password1");
			this.pass2=(Gtk.Entry)this.builder.get_object("password2");
			this.fill_config();
			do {
				main_w.show();
				var retval=main_w.run();
				main_w.hide();
				if (retval==1) {
					if (this.pass1.get_text()!=this.pass2.get_text()) { // the passwords don't match
						var msg=new show_message(_("The passwords don't match. Try again."));
						msg=null;
						continue;
					}
					var pwd=new ask_password();
					if (0!=pwd.run(this.config.password)) {
						var msg=new show_message(_("Incorrect password"));
						msg=null;
						continue;
					}
					this.restore_config();
				}
				break;
			} while(true);
			main_w.destroy();
		}

		private void fill_config() {
			this.time_holidays.set_value(this.config.time_holidays);
			this.time_no_holidays.set_value(this.config.time_no_holidays);
			this.sunday.active=this.config.holidays[0];
			this.monday.active=this.config.holidays[1];
			this.tuesday.active=this.config.holidays[2];
			this.wednesday.active=this.config.holidays[3];
			this.thursday.active=this.config.holidays[4];
			this.friday.active=this.config.holidays[5];
			this.saturday.active=this.config.holidays[6];
		}

		private void restore_config() {
			this.config.time_holidays=(int)this.time_holidays.get_value();
			this.config.time_no_holidays=(int)this.time_no_holidays.get_value();
			this.config.holidays[0]=this.sunday.active;
			this.config.holidays[1]=this.monday.active;
			this.config.holidays[2]=this.tuesday.active;
			this.config.holidays[3]=this.wednesday.active;
			this.config.holidays[4]=this.thursday.active;
			this.config.holidays[5]=this.friday.active;
			this.config.holidays[6]=this.saturday.active;
			if (this.pass1.get_text()!="") {
				Checksum checksum = new Checksum (ChecksumType.MD5);
				var text=this.pass1.get_text();
				checksum.update(text.data,text.length);
				this.config.password=checksum.get_string();
			}
			this.config.write_configuration();
		}
	}
}