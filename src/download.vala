// Copyright 2020 Łukasz Pankowski <lukpank at o2 dot pl>. All rights
// reserved.  This source code is licensed under the terms of the MIT
// license. See LICENSE file for details.

namespace Vydl {

    public async string? choose_file_name (Gtk.Window? parent, string filename) {
        SourceFunc return_result = choose_file_name.callback;
        var dlg = new Gtk.FileChooserDialog (_("Save as"), parent, Gtk.FileChooserAction.SAVE);
        dlg.add_buttons (_("Save"), Gtk.ResponseType.OK, _("Cancel"), Gtk.ResponseType.CANCEL);
        dlg.do_overwrite_confirmation = true;
        var filter = new Gtk.FileFilter ();
        filter.add_pattern ("*");
        filter.set_name (_("All files"));
        dlg.add_filter (filter);
        filter = new Gtk.FileFilter ();
        filter.set_name (_("Video files"));
        filter.add_mime_type ("video/*");
        dlg.add_filter (filter);
        dlg.set_current_name (filename);
        dlg.show_all ();
        string? result = null;
        dlg.response.connect ((_, resp) => {
                if (resp == Gtk.ResponseType.OK) {
                    var file = dlg.get_file ();
                    result = file.get_path ();
                }
                return_result ();
            });
        yield;
        dlg.destroy ();
        return result;
    }

    public async bool confirmation (Gtk.Window parent, string message) {
        SourceFunc return_result = confirmation.callback;
        var dlg = new Gtk.MessageDialog (parent, Gtk.DialogFlags.MODAL | Gtk.DialogFlags.DESTROY_WITH_PARENT,
                                         Gtk.MessageType.QUESTION, Gtk.ButtonsType.YES_NO, message);
        dlg.title = _("Confirmation");
        dlg.show_all ();
        bool result = false;
        dlg.response.connect ((dlg, resp) => {
                result = resp == Gtk.ResponseType.YES;
                return_result ();
            });
        yield;
        dlg.destroy ();
        return result;
    }
}

public class Vydl.Downloader : Gtk.Dialog {

    private static Regex downloadRegex = /\[download\] +([0-9.]+)%/;
    public string file_title { get; construct; }
    public string filename { get; construct; }
    public string url { get; construct; }
    public string format_id { get; construct; }
    private bool finished = false;
    private Gtk.ProgressBar progress;
    private Gtk.Button button;
    private Subprocess process;

    public Downloader (Gtk.Window? parent, string file_title, string filename, string url, string format_id) {
        Object (file_title: file_title, filename: filename, url: url, format_id: format_id,
                title: _("Downloading"), border_width: 20, default_width: 640, default_height: 300,
                transient_for: parent, modal: true);
    }

    construct {
        var box = this.get_content_area () as Gtk.Box;
        var label = new Gtk.Label.with_mnemonic (this.file_title);
        box.pack_start (label, true, true, 20);
        this.progress = new Gtk.ProgressBar ();
        this.progress.text = _("Connecting...");
        this.progress.show_text = true;
        box.pack_start (this.progress, true, true, 20);
        this.button = this.add_button (_("Cancel"), Gtk.ResponseType.CLOSE) as Gtk.Button;
    }

    public bool start () {
        try {
            var escaped = this.filename.replace ("%", "%%");
            this.process = new Subprocess (SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE,
                                           "youtube-dl", "-o", escaped, "--newline", "--no-continue",
                                           "-f", this.format_id, "--", this.url);
            var stdout = new DataInputStream (this.process.get_stdout_pipe ());
            this.process_stdout.begin (stdout);
            var stderr = this.process.get_stderr_pipe ();
            this.process_stderr.begin (stderr);
            this.show_all ();
            this.response.connect (on_response);
            return true;
        } catch (Error e) {
            Vydl.show_error (this, e.message, this.cancel);
            return false;
        }
    }

    public async void on_response (Gtk.Dialog dlg, int response) {
        if (response == Gtk.ResponseType.CLOSE && ! finished &&
            ! yield Vydl.confirmation (this, _("Cancel downloading?"))) {
            return;
        }
        if (! this.finished) {
            this.finished = true;
            this.process.force_exit ();
            try {
                File f = File.new_for_path (this.filename + ".part");
                f.delete ();
            } catch (Error e) {
                if (! (e is FileError.NOENT)) {
                    Vydl.show_error (this, e.message, null);
                }
            }
        }
        this.destroy ();
    }

    private void cancel () {
        this.response (Gtk.ResponseType.CANCEL);
    }

    private async void process_stderr (InputStream stderr) {
        try {
            size_t length;
            var buf = new uint8[4096];
            yield stderr.read_all_async (buf, 0, null, out length);
            while ((yield stderr.skip_async (4096)) > 0) {}
            yield this.process.wait_async ();
            bool normal_exit = this.process.get_if_exited ();
            if (normal_exit && this.process.get_exit_status () != 0 || ! normal_exit && ! this.finished) {
                buf[int.min ((int) length, (int) buf.length - 1)] = '\0';
                Vydl.show_error (this, (length > 0) ? (string) buf : _("Subprocess error."), this.cancel);
                return;
            }
        } catch (Error e) {
            Vydl.show_error (this, e.message, null);
        }
        this.finished = true;
    }

    private async void process_stdout (DataInputStream stdout) {
        try {
            while (true) {
                string? line = yield stdout.read_line_async ();
                if (line == null) {
                    break;
                }
                update_progress (line);
            }
            this.button.label = _("Close");
        } catch (Error e) {
            Vydl.show_error (this, e.message, null);
        }
    }

    private void update_progress (string line) {
        MatchInfo m;
        if (Downloader.downloadRegex.match (line, 0, out m)) {
            int pos;
            m.fetch_pos (1, out pos, null);
            this.progress.fraction = float.parse (m.fetch (1)) / 100;
            this.progress.text = line.substring (pos);
        }
    }
}
