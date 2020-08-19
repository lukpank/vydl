// Copyright 2020 Łukasz Pankowski <lukpank at o2 dot pl>. All rights
// reserved.  This source code is licensed under the terms of the MIT
// license. See LICENSE file for details.

namespace Vydl {

    public delegate void VoidCallback ();

    public void show_error (Gtk.Window parent, string message, VoidCallback? fn) {
        var dlg = new Gtk.MessageDialog (parent, Gtk.DialogFlags.MODAL | Gtk.DialogFlags.DESTROY_WITH_PARENT,
                                         Gtk.MessageType.ERROR, Gtk.ButtonsType.CLOSE, message);
        dlg.title = "Error";
        dlg.response.connect (() => {
                dlg.destroy ();
                if (fn != null) {
                    fn ();
                }
            });
        dlg.run ();
    }
}

public class Vydl.MainWindow : Gtk.Window {

    private Gtk.Entry entry;
    private Gtk.Button search;
    private Gtk.Button download;
    private Gtk.TreeView treeview;
    private Gtk.ListStore model;
    private bool searching = false;
    private string? url = null;
    private Vydl.Metadata metadata = null;
    private Vydl.Format format = null;
    private int[] row_indices = null;

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
        this.entry = new Gtk.Entry ();
        hbox.pack_start (this.entry, true, true, 0);
        this.search = new Gtk.Button.with_label ("Search");
        hbox.pack_start (this.search, false, false, 0);
        var sw = new Gtk.ScrolledWindow (null, null);
        vbox.pack_start (sw, true, true, 10);
        this.treeview = new Gtk.TreeView ();
        setup_tree_view (this.treeview);
        sw.add (treeview);
        this.download = new Gtk.Button.with_label ("Download");
        vbox.pack_start (this.download, false, false, 10);
        this.search.clicked.connect (this.start_search);
        this.download.clicked.connect (this.start_download);
        this.entry.changed.connect (this.update);
        this.treeview.cursor_changed.connect (this.select_row);
        this.update ();
    }

    private void setup_tree_view (Gtk.TreeView view) {
        this.model = new Gtk.ListStore (3, typeof (string), typeof (string), typeof (string));
        view.set_model (model);
        view.insert_column_with_attributes (-1, "Size", new Gtk.CellRendererText (), "text", 0);
        view.insert_column_with_attributes (-1, "Quality", new Gtk.CellRendererText (), "text", 1);
        view.insert_column_with_attributes (-1, "Title", new Gtk.CellRendererText (), "text", 2);
    }

    private void update () {
        this.search.set_sensitive (! this.searching && this.entry.text.length > 0);
        this.download.set_sensitive (this.format != null);
    }

    private async void start_search () {
        try {
            this.searching = true;
            this.format = null;
            this.model.clear ();
            this.update ();
            this.url = this.entry.text;
            var p = new Subprocess (SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE,
                                    "youtube-dl", "-j", "--", this.url);
            string output;
            string error;
            yield p.communicate_utf8_async (null, null, out output, out error);
            if (p.get_exit_status () != 0) {
                Vydl.show_error (this, (error != "") ? error : "Subprocess error.", null);
                this.searching = false;
                this.update ();
                return;
            }
            var j = Json.from_string (output);
            if (j == null) {
                this.searching = false;
                this.update ();
                Vydl.show_error (this, "JSON parsing error.", null);
                return;
            }
            this.metadata = new Vydl.Metadata (j);
            Gtk.TreeIter iter;
            this.row_indices = new int[this.metadata.formats.length];
            int i = 0;
            int k = 0;
            foreach (var fmt in this.metadata.formats) {
                if (fmt.acodec != "none" && fmt.vcodec != "none") {
                    this.model.append (out iter);
                    model.set (iter, 0, fmt.file_size (), 1, fmt.quality (), 2, this.metadata.title);
                    this.row_indices[k++] = i;
                }
                i++;
            }
        } catch (Error e) {
            Vydl.show_error (this, e.message, null);
        }
        this.searching = false;
        this.update ();
    }

    private void start_download () {
        string? filename = this.metadata.filename;
        int i = filename.last_index_of_char ('.');
        if (i != -1) {
            filename = filename.substring (0, i) + "." + this.format.ext;
        }
        filename = Vydl.choose_file_name (this, filename);
        if (filename != null) {
            var dlg = new Vydl.Downloader (metadata.title, filename, this.url, this.format.format_id);
            if (dlg.start ()) {
                dlg.set_transient_for (this);
                dlg.show_all ();
                dlg.run ();
            }
            dlg.destroy ();
        }
    }

    private void select_row (Gtk.TreeView treeview) {
        unowned Gtk.TreeModel model;
        Gtk.TreeIter iter;
        if (this.treeview.get_selection ().get_selected (out model, out iter)) {
            var path = model.get_path (iter);
            if (path.get_depth () == 1) {
                var idx = this.row_indices[path.get_indices ()[0]];
                this.format = this.metadata.formats[idx];
                this.update ();
            }
        }
    }
}

public static int main (string[] args) {
    Gtk.init (ref args);
    var w = new Vydl.MainWindow ();
    w.show_all ();
    Gtk.main ();
    return 0;
}
