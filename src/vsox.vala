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

public class Effect {
	public string name;
	public Gtk.Scale scale;

	public Effect (string name, Gtk.Scale scale) {
		this.name  = name;
		this.scale = scale;
	}
}

public class Main : Object 
{
	/* 
	 * Uncomment this line when you are done testing and building a tarball
	 * or installing
	 */
	//const string UI_FILE = Config.PACKAGE_DATA_DIR + "/ui/" + "vsox.ui";
	const string UI_FILE = "src/vsox.ui";

	// Gtk.Scale scale1;
	Gtk.Window window;
	int soxnull_module_id = -1;
	GLib.Pid? sox_pid = null;
	Gtk.ListStore liststore1;
	Gtk.ComboBox add_effect_combobox;
	Gtk.Grid effects_grid;
	Gee.List<Effect> effects = new Gee.ArrayList<Effect>();

	public void close_sox_process () {
		if (sox_pid != null) {
			Posix.kill ((!)sox_pid, Posix.SIGINT);
			Process.close_pid ((!)sox_pid);
		}
		sox_pid = null;
	}

	public void spawn_sox_async () {
		Gee.List<string?> argv = new Gee.ArrayList<string?> ();
		argv.add ("sox");
		// Input
		argv.add_all_array ({"-t", "pulseaudio", "default"});
		// Output
		argv.add_all_array ({"-t", "pulseaudio", "soxnull"});
		// Effects
		argv.add_all (get_sox_effects_cmd_args ());
		// Important: spawn_async needs the passed array to be null-terminated!
		argv.add (null);
		string cmd_line = "";
		foreach (var arg in argv) {
			cmd_line += arg + " ";
		}
		stdout.puts (cmd_line + "\n");
		try {
			Process.spawn_async (null, argv.to_array (), null,
			                     SpawnFlags.SEARCH_PATH, null, out sox_pid);
		}
		catch (SpawnError e) {
			stderr.printf ("Could not load sox: %s\n", e.message);
		}
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

	public Gee.ArrayList<string> get_sox_effects_cmd_args () {
		var l = new Gee.ArrayList<string> ();
		foreach (var effect in effects) {
			if (effect.name == "pitch") {
				l.add ("pitch"); 
				l.add (effect.scale.get_value ().to_string ());
			}
			else if (effect.name == "treble") {
				l.add ("treble"); 
				l.add (effect.scale.get_value ().to_string ());
			}
			else if (effect.name == "bass") {
				l.add ("bass"); 
				l.add (effect.scale.get_value ().to_string ());
			}
		}
		return l;
	}

	public Main () {
		try 
		{
			var builder = new Gtk.Builder ();
			builder.add_from_file (UI_FILE);
			builder.connect_signals (this);

			window = builder.get_object ("window") as Gtk.Window;
			liststore1 = builder.get_object ("liststore1") as Gtk.ListStore;
			add_effect_combobox = builder.get_object ("add_effect_combobox")
				as Gtk.ComboBox;
			effects_grid = builder.get_object ("effects_grid") as Gtk.Grid;
			Gtk.TreeIter iter;
			liststore1.append (out iter);
			liststore1.@set (iter, 0, "Pitch", 1, "pitch");
			liststore1.append (out iter);
			liststore1.@set (iter, 0, "Treble", 1, "treble");
			liststore1.append (out iter);
			liststore1.@set (iter, 0, "Bass", 1, "bass");
			window.show_all ();
			load_soxnull_sink_sync ();
		} 
		catch (Error e) {
			stderr.printf ("Could not load UI: %s\n", e.message);
		}
	}

	~Main () {
		unload_soxnull_sink_sync ();
		close_sox_process ();
	}

	[CCode (instance_pos = -1)]
	public void on_destroy (Gtk.Widget window) {
		Gtk.main_quit();
	}

	[CCode (instance_pos = -1)]
	public void on_add_effect_button_clicked (Gtk.Button button) {
		Gtk.TreeIter iter;
		add_effect_combobox.get_active_iter (out iter);
		Value effect_name_val;
		liststore1.get_value (iter, 1, out effect_name_val);
		string effect_name = (string)effect_name_val;
		if (effect_name == "")
			return;
		effects_grid.insert_row (effects.size + 1);
		Gtk.Scale settings = null;
		string label_text = "";
		if (effect_name == "pitch") {
			label_text = "Pitch";
			Gtk.Scale scale = new Gtk.Scale (Gtk.Orientation.HORIZONTAL, null);
			scale.set_range (-1000, 1000);
			scale.hexpand = true;
			settings = scale;
		}
		else if (effect_name == "treble") {
			label_text = "Treble";
			Gtk.Scale scale = new Gtk.Scale (Gtk.Orientation.HORIZONTAL, null);
			scale.set_range (-20, 20);
			scale.hexpand = true;
			settings = scale;
		}
		else if (effect_name == "bass") {
			label_text = "Bass";
			Gtk.Scale scale = new Gtk.Scale (Gtk.Orientation.HORIZONTAL, null);
			scale.set_range (-20, 20);
			scale.hexpand = true;
			settings = scale;
		}
		Gtk.Label label = new Gtk.Label (label_text);
		label.halign = Gtk.Align.START;
		effects_grid.attach (label, 1, effects.size + 1);
		effects_grid.attach (settings, 2, effects.size + 1);
		effects_grid.show_all ();
		effects.add (new Effect (effect_name, settings));
	}

	[CCode (instance_pos = -1)]
	public void on_apply_button_clicked (Gtk.Button button) {
		if (effects.size == 0) {
			var dialog = new Gtk.MessageDialog (window,
			                                    Gtk.DialogFlags.MODAL, 
			                                    Gtk.MessageType.ERROR,
			                                    Gtk.ButtonsType.OK,
			                                    "No effects added");
			dialog.run ();
			dialog.destroy ();
			return;
		}
		close_sox_process ();
		spawn_sox_async ();
	}

	static int main (string[] args) {
		Gtk.init (ref args);
		Main* app = new Main ();
		try {
			Gtk.main ();
		}
		finally {
			delete app;
		}
		return 0;
	}
}

