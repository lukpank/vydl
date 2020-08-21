// Copyright 2020 Łukasz Pankowski <lukpank at o2 dot pl>. All rights
// reserved.  This source code is licensed under the terms of the MIT
// license. See LICENSE file for details.

public class Vydl.Format {

    public string format_id;
    public string format_note;
    public string ext;
    public int64 width;
    public int64 height;
    public int64 filesize;
    public string acodec;
    public string vcodec;

    public Format (Json.Object fmt) {
        this.format_id = fmt.get_string_member ("format_id");
        this.format_note = fmt.get_string_member ("format_note");
        this.ext = fmt.get_string_member ("ext");
        var width = fmt.get_member ("width");
        this.width = (width.is_null ()) ? -1 : width.get_int ();
        var height = fmt.get_member ("height");
        this.height = (height.is_null ()) ? -1 : height.get_int ();
        var filesize = fmt.get_member ("filesize");
        this.filesize = (filesize.is_null ()) ? -1 : filesize.get_int ();
        this.acodec = fmt.get_string_member ("acodec");
        this.vcodec = fmt.get_string_member ("vcodec");
    }

    public string file_size () {
        const int64 mi = 1024 * 1204;
        const int64 gi = 1024 * mi;
        if (filesize == -1) {
            return _("(best)");
        } else if (filesize >= gi) {
            var v = ((double) (filesize / mi)) / 1024;
            return "%.2f GiB".printf (v);
        } else if (filesize >= mi) {
            var v = ((double) (filesize / 1024)) / 1024;
            return "%.2f MiB".printf (v);
        } else if (filesize >= 1024) {
            var v = ((double) filesize) / 1024;
            return "%.2f MiB".printf (v);
        } else {
            return @"$(this.filesize) B";
        }
    }

    public string quality () {
        if (width != -1 && height != -1) {
            return @"$(this.width)x$(this.height) ($(this.format_note))";
        } else {
            return @"($(this.format_note))";
        }
    }
}

public class Vydl.Metadata {

    public string title;
    public string filename;
    public int64 duration;
    public Vydl.Format[] formats;

    public Metadata (Json.Node j) {
        var o = j.get_object ();
        this.title = o.get_string_member ("title");
        this.filename = o.get_string_member ("_filename");
        this.duration = o.get_int_member ("duration");
        var formats = o.get_array_member ("formats");
        uint length = formats.get_length ();
        this.formats.resize ((int) length);
        for (uint i = 0; i < length; i++) {
            this.formats[i] = new Vydl.Format (formats.get_object_element (i));
        }
    }
}
