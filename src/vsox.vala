/* -*- Mode: C; indent-tabs-mode: t; c-basic-offset: 4; tab-width: 4 -*-  */
/*
 * main.c
 * Copyright (C) 2015 Prometheus <prometheus@unterderbruecke.de>
 * 
 * vsox is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * vsox is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

public class Main : Object 
{

	/* 
	 * Uncomment this line when you are done testing and building a tarball
	 * or installing
	 */
	const string UI_FILE = Config.PACKAGE_DATA_DIR + "/ui/" + "vsox.ui";
	// const string UI_FILE = "src/vsox.ui";

	/* ANJUTA: Widgets declaration for vsox.ui - DO NOT REMOVE */

	Gtk.Button button1;
	Gtk.Scale scale1;
	Gtk.Window window;
	int soxnull_module_id = -1;

	public void killall_sox_sync () throws SpawnError {
		Process.spawn_sync (null, {
			"/usr/bin/killall",
			"sox"
		}, null, 0, null);
	}

	public void spawn_sox_async () throws SpawnError {
		GLib.Pid pid;
		Process.spawn_async (null, {
			"/usr/bin/sox", 
			"-t", "pulseaudio", "default", 
			"-t", "pulseaudio", "soxnull",
			"pitch", scale1.get_value ().to_string ()
		}, null, 0, null, out pid);
	}

	public void load_soxnull_sink_sync () throws SpawnError {
		string module_id_text = "";
		Process.spawn_sync (null, {
			"/usr/bin/pactl", 
			"load-module", 
			"module-null-sink",
			"sink_name=soxnull",
			"sink_properties=device.description=\"soxnull\""
		}, null, 0, null, out module_id_text, null);
		module_id_text.scanf ("%d", &soxnull_module_id);
	}

	public void unload_soxnull_sink_sync () throws SpawnError {
		if (soxnull_module_id != -1) {
			Process.spawn_sync (null, {
				"/usr/bin/pactl", 
				"unload-module", 
				soxnull_module_id.to_string ()
			}, null, 0, null);
		}
	}

	public Main ()
	{
		try 
		{
			var builder = new Gtk.Builder ();
			builder.add_from_file (UI_FILE);
			builder.connect_signals (this);

			window = builder.get_object ("window") as Gtk.Window;
			scale1 = builder.get_object ("scale1") as Gtk.Scale;
			scale1.set_range (-1000, 1000);
			button1 = builder.get_object ("button1") as Gtk.Button;
			button1.clicked.connect (() => {
				killall_sox_sync ();
				spawn_sox_async ();
			});
			window.show_all ();
		} 
		catch (Error e) {
			stderr.printf ("Could not load UI: %s\n", e.message);
		}
	}

	[CCode (instance_pos = -1)]
	public void on_destroy (Gtk.Widget window) 
	{
		Gtk.main_quit();
	}

	static int main (string[] args) 
	{
		Gtk.init (ref args);
		var app = new Main ();

		app.load_soxnull_sink_sync ();
		app.killall_sox_sync ();
		Gtk.main ();
		app.unload_soxnull_sink_sync ();
		app.killall_sox_sync ();
		
		return 0;
	}
}

