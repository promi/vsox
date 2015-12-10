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
	public Gtk.Scale? scale1;
	public Gtk.Scale? gain_in_scale;
	public Gtk.Scale? gain_out_scale;
	public Gtk.Scale? delay_scale;
	public Gtk.Scale? decay_scale;
	public Gtk.Scale? speed_scale;
	public Gtk.Scale? depth_scale;
	public Gtk.ToggleButton? sinus_triangle_toggle_button;
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
			l.add (effect.name); 
			if (effect.name == "pitch") {
				l.add (effect.scale1.get_value ().to_string ());
			}
			else if (effect.name == "treble") {
				l.add (effect.scale1.get_value ().to_string ());
			}
			else if (effect.name == "bass") {
				l.add (effect.scale1.get_value ().to_string ());
			}
			else if (effect.name == "chorus") {
				// gain-in 0.7
				l.add (effect.gain_in_scale.get_value ().to_string ());
				// gain-out 0.9
				l.add (effect.gain_out_scale.get_value ().to_string ());
				// delay 55
				l.add (effect.delay_scale.get_value ().to_string ()); 
				// decay 0.4
				l.add (effect.decay_scale.get_value ().to_string ());
				// speed 0.25
				l.add (effect.speed_scale.get_value ().to_string ());
				// depth 2
				l.add (effect.depth_scale.get_value ().to_string ());
				// sinus <-> triangle -s -t
				l.add (effect.sinus_triangle_toggle_button.active ? "-t" : "-s");
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
			liststore1.append (out iter);
			liststore1.@set (iter, 0, "Chorus", 1, "chorus");
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
		var effect = new Effect ();
		effect.name = effect_name;
		Gtk.Widget container = null;
		string label_text = "";
		if (effect_name == "pitch") {
			label_text = "Pitch (cents)";
			effect.scale1 = new Gtk.Scale (Gtk.Orientation.HORIZONTAL, null);
			effect.scale1.set_range (-1000, 1000);
			effect.scale1.hexpand = true;
			container = effect.scale1;
		}
		else if (effect_name == "treble") {
			label_text = "Treble (dB)";
			effect.scale1 = new Gtk.Scale (Gtk.Orientation.HORIZONTAL, null);
			effect.scale1.set_range (-20, 20);
			effect.scale1.hexpand = true;
			container = effect.scale1;
		}
		else if (effect_name == "bass") {
			label_text = "Bass (dB)";
			effect.scale1 = new Gtk.Scale (Gtk.Orientation.HORIZONTAL, null);
			effect.scale1.set_range (-20, 20);
			effect.scale1.hexpand = true;
			container = effect.scale1;
		}
		else if (effect_name == "chorus") {
			label_text = "Chorus";
			var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
			effect.gain_in_scale = new Gtk.Scale (Gtk.Orientation.HORIZONTAL, null);
			effect.gain_in_scale.set_range (0, 1);
			effect.gain_in_scale.set_value (0.7);
			effect.gain_in_scale.hexpand = true;
			box.pack_start (effect.gain_in_scale);
			effect.gain_out_scale = new Gtk.Scale (Gtk.Orientation.HORIZONTAL, null);
			effect.gain_out_scale.set_range (0, 1);
			effect.gain_out_scale.set_value (0.9);
			effect.gain_out_scale.hexpand = true;
			box.pack_start (effect.gain_out_scale);
			effect.delay_scale = new Gtk.Scale (Gtk.Orientation.HORIZONTAL, null);
			effect.delay_scale.set_range (0, 200);
			effect.delay_scale.set_value (55);
			effect.delay_scale.hexpand = true;
			box.pack_start (effect.delay_scale);
			effect.decay_scale = new Gtk.Scale (Gtk.Orientation.HORIZONTAL, null);
			effect.decay_scale.set_range (0, 1);
			effect.decay_scale.set_value (0.4);
			effect.decay_scale.hexpand = true;
			box.pack_start (effect.decay_scale);
			effect.speed_scale = new Gtk.Scale (Gtk.Orientation.HORIZONTAL, null);
			effect.speed_scale.set_range (0, 1);
			effect.speed_scale.set_value (0.25);
			effect.speed_scale.hexpand = true;
			box.pack_start (effect.speed_scale);
			effect.depth_scale = new Gtk.Scale (Gtk.Orientation.HORIZONTAL, null);
			effect.depth_scale.set_range (0, 10);
			effect.depth_scale.set_value (2);
			effect.depth_scale.hexpand = true;
			box.pack_start (effect.depth_scale);
			effect.sinus_triangle_toggle_button = new Gtk.ToggleButton ();
			effect.sinus_triangle_toggle_button.set_label ("Triangle");
			// effect.sinus_triangle_toggle_button.hexpand = false;
			box.pack_start (effect.sinus_triangle_toggle_button);
			container = box;
		}
		Gtk.Label label = new Gtk.Label (label_text);
		label.halign = Gtk.Align.START;
		effects_grid.attach (label, 1, effects.size + 1);
		effects_grid.attach (container, 2, effects.size + 1);
		effects_grid.show_all ();
		effects.add (effect);
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

