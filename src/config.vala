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

	public class configuration:Object {
		public bool holidays[7];
		public int time_holidays;
		public int time_no_holidays;
		public string password;
		public bool disabled;

		public configuration() {
			for(int i=1;i<6;i++) {
				this.holidays[i]=false;
			}
			this.holidays[0]=true; // sunday
			this.holidays[6]=true; // saturday
			this.time_holidays=240;
			this.time_no_holidays=120;
			this.disabled=false;
			this.password="b409f0ef3e3bcae3d6e32cd084ccc20a"; // by default, password is "pequerrechos"
			this.read_configuration();
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
			uint8 buffer2[2];
			string retval="";
			buffer2[1]=0;
			try {
				do {
					stream.read(buffer);
					if (buffer[0]!=0) {
						buffer2[0]=buffer[0];
						retval+=((string)buffer2);
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
	}
}
