// Copyright 2020 Łukasz Pankowski <lukpank at o2 dot pl>. All rights
// reserved.  This source code is licensed under the terms of the MIT
// license. See LICENSE file for details.

public class Vydl.MainWindow : Gtk.Window {

    construct {
        this.border_width = 10;
        this.default_width = 640;
        this.default_height = 480;
        this.title = "VYDL";
        this.destroy.connect (Gtk.main_quit);
        var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 10);
        this.add (vbox);
        var hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
        vbox.pack_start (hbox, false, false, 0);
        var entry = new Gtk.Entry ();
        hbox.pack_start (entry, true, true, 0);
        var search = new Gtk.Button.with_label ("Search");
        hbox.pack_start (search, false, false, 0);
        var sw = new Gtk.ScrolledWindow (null, null);
        vbox.pack_start (sw, true, true, 10);
        var treeview = new Gtk.TreeView ();
        sw.add (treeview);
        var download = new Gtk.Button.with_label ("Download");
        vbox.pack_start (download, false, false, 10);
    }
}

public static int main (string[] args) {
    Gtk.init (ref args);
    var w = new Vydl.MainWindow ();
    w.show_all ();
    Gtk.main ();
    return 0;
}
