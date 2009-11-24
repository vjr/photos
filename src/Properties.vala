/* Copyright 2009 Yorba Foundation
 *
 * This software is licensed under the GNU LGPL (version 2.1 or later).
 * See the COPYING file in this distribution. 
 */

private abstract class Properties : Gtk.HBox {
    protected Gtk.Label label = new Gtk.Label("");
    protected Gtk.Label info = new Gtk.Label(""); 
    protected string basic_properties_labels;
    protected string basic_properties_info;
    protected bool first_line;

    public Properties() {
        label.set_justify(Gtk.Justification.RIGHT);
        label.set_alignment(0, (float) 5e-1);
        info.set_alignment(0, (float) 5e-1);
        pack_start(label, false, false, 3);
        pack_start(info, true, true, 3);
        
        info.set_ellipsize(Pango.EllipsizeMode.END);
    }

    protected void add_line(string label, string info) {
        if (!first_line) {
            basic_properties_labels += "\n";
            basic_properties_info += "\n";
        }
        basic_properties_labels += label;
        basic_properties_info += info;
        first_line = false;
    }
    
    protected string get_prettyprint_time(Time time) {
        string timestring = time.format(_("%I:%M %p"));
        
        if (timestring[0] == '0')
            timestring = timestring.substring(1, -1);
        
        return timestring;
    }

    protected string get_prettyprint_date(Time date) {
        string date_string = null;
        Time today = Time.local(time_t());
        if (date.day_of_year == today.day_of_year && date.year == today.year) {
            date_string = _("Today");
        } else if (date.day_of_year == (today.day_of_year - 1) && date.year == today.year) {
            date_string = _("Yesterday");
        } else {
            date_string = format_local_date(date);
        }

        return date_string;
    }

    protected void set_text() {
        label.set_markup(GLib.Markup.printf_escaped("<span font_weight=\"bold\">%s</span>", basic_properties_labels));
        info.set_text(basic_properties_info);
    }

    protected virtual void get_single_properties(DataView view) {
    }

    protected virtual void get_multiple_properties(Gee.Iterable<DataView>? iter) {
    }

    protected virtual void get_properties(Page current_page) {
        ViewCollection view = current_page.get_view();
        if (view == null)
            return;

        // summarize selected items, if none selected, summarize all
        int count = view.get_selected_count();
        Gee.Iterable<DataView> iter = null;
        if (count != 0) {
            iter = view.get_selected();
        } else {
            count = view.get_count();
            iter = (Gee.Iterable<DataView>) view.get_all();
        }
        
        if (iter == null || count == 0)
            return;

        if (count == 1) {
            foreach (DataView item in iter) {
                get_single_properties(item);                
                break;
            }
        } else {
            get_multiple_properties(iter);
        }
    }

    protected virtual void clear_properties() {
        basic_properties_labels = "";
        basic_properties_info = "";
        first_line = true;
    }

    public virtual void update_properties(Page page) {
        clear_properties();
        get_properties(page);
    }
    
}

private class BasicProperties : Properties {
    private string title;
    private time_t start_time = time_t();
    private time_t end_time = time_t();
    private Dimensions dimensions;
    private int photo_count;      
    private int event_count;
    private string exposure;
    private string aperture;
    private string iso;

    private override void clear_properties() {
        base.clear_properties();
        title = "";
        start_time = 0;
        end_time = 0;
        dimensions = Dimensions(0,0);
        photo_count = -1;
        event_count = -1;
        exposure = "";
        aperture = "";
        iso = "";
    }

    private override void get_single_properties(DataView view) {
        base.get_single_properties(view);

        DataSource source = view.get_source();

        title = source.get_name();
        
        if (source is PhotoSource) {
            PhotoSource photo_source = (PhotoSource) source;
            
            start_time = photo_source.get_exposure_time();
            end_time = start_time;
            
            dimensions = photo_source.get_dimensions();

            Exif.Data exif = photo_source.get_exif();
            exposure = Exif.get_exposure(exif);
            aperture = Exif.get_aperture(exif);
            iso = Exif.get_iso(exif);

        } else if (source is EventSource) {
            EventSource event_source = (EventSource) source;

            start_time = event_source.get_start_time();
            end_time = event_source.get_end_time();

            photo_count = event_source.get_photo_count();
        }
    }

    private override void get_multiple_properties(Gee.Iterable<DataView>? iter) {
        base.get_multiple_properties(iter);

        photo_count = 0;
        foreach (DataView view in iter) {
            DataSource source = view.get_source();
            
            if (source is PhotoSource) {
                PhotoSource photo_source = (PhotoSource) source;
                    
                time_t exposure_time = photo_source.get_exposure_time();

                if (exposure_time != 0) {
                    if (start_time == 0 || exposure_time < start_time)
                        start_time = exposure_time;

                    if (end_time == 0 || exposure_time > end_time)
                        end_time = exposure_time;
                }
                
                photo_count++;
            } else if (source is EventSource) {
                EventSource event_source = (EventSource) source;
          
                if (event_count == -1)
                    event_count = 0;

                if ((start_time == 0 || event_source.get_start_time() < start_time) &&
                    event_source.get_start_time() != 0 ) {
                    start_time = event_source.get_start_time();
                }
                if ((end_time == 0 || event_source.get_end_time() > end_time) &&
                    event_source.get_end_time() != 0 ) {
                    end_time = event_source.get_end_time();
                } else if (end_time == 0 || event_source.get_start_time() > end_time) {
                    end_time = event_source.get_start_time();
                }

                photo_count += event_source.get_photo_count();
                event_count++;
            }
        }
    }

    private override void get_properties(Page current_page) {
        base.get_properties(current_page);

        if (end_time == 0)
            end_time = start_time;
        if (start_time == 0)
            start_time = end_time;
    }

    public override void update_properties(Page page) {
        base.update_properties(page);

        if (title != "")
            add_line(_("Title:"), title);

        if (photo_count >= 0) {
            string label = _("Items:");
  
            if (event_count >= 0) {
                string event_num_string;
                if (event_count == 1)
                    event_num_string = _("%d Event");
                else
                    event_num_string = _("%d Events");

                add_line(label, event_num_string.printf(event_count));
                label = "";
            }

            string photo_num_string;
            if (photo_count == 1)
                photo_num_string = _("%d Photo");
            else
                photo_num_string = _("%d Photos");

            add_line(label, photo_num_string.printf(photo_count));
        }

        if (start_time != 0) {
            string start_date = get_prettyprint_date(Time.local(start_time));
            string start_time = get_prettyprint_time(Time.local(start_time));
            string end_date = get_prettyprint_date(Time.local(end_time));
            string end_time = get_prettyprint_time(Time.local(end_time));

            if (start_date == end_date) {
                // display only one date if start and end are the same
                add_line(_("Date:"), start_date);

                if (start_time == end_time) {
                    // display only one time if start and end are the same
                    add_line(_("Time:"), start_time);
                } else {
                    // display time range
                    add_line(_("From:"), start_time);
                    add_line(_("To:"), end_time);
                }
            } else {
                // display date range
                add_line(_("From:"), start_date);
                add_line(_("To:"), end_date);
            }
        }

        if (dimensions.has_area()) {
            string label = _("Size:");

            if (dimensions.has_area()) {
                add_line(label, "%d x %d".printf(dimensions.width, dimensions.height));
                label = "";
            }
        }

        if (exposure != "" && aperture != "" && iso != "") {
            add_line(_("Exposure:"), exposure + ", " + aperture);
            add_line("","ISO " + iso);
        }

        set_text();
    }
}

private class ExtendedPropertiesWindow : Gtk.Window {
    private ExtendedProperties properties = null;
    private const int FRAME_BORDER = 6;

    private class ExtendedProperties : Properties {
        private const string NO_VALUE = " --";
        private string file_path;
        private uint64 filesize;
        private Dimensions original_dim;
        private string camera_make;
        private string camera_model;
        private string flash;
        private string focal_length;
        private double gps_lat;
        private string gps_lat_ref;
        private double gps_long;
        private string gps_long_ref;
        private string artist;
        private string copyright;
        private string software;
            
        protected override void clear_properties() {
            base.clear_properties();

            file_path = "";
            filesize = 0;
            original_dim = Dimensions(0,0);
            camera_make = "";
            camera_model = "";
            flash = "";
            focal_length = "";
            gps_lat = -1;
            gps_lat_ref = "";
            gps_long = -1;
            gps_long_ref = "";
            artist = "";
            copyright = "";
            software = "";
        }

        protected override void get_single_properties(DataView view) {
            base.get_single_properties(view);

            DataSource source = view.get_source();

            if (source is PhotoSource) {
                if (source is TransformablePhoto)                
                    file_path = ((TransformablePhoto) source).get_file().get_path();

                filesize = ((PhotoSource) source).get_filesize();

                Exif.Data exif = ((PhotoSource) source).get_exif();

                if (exif != null) {
                    Exif.get_dimensions(exif, out original_dim);
                    camera_make = Exif.get_camera_make(exif);
                    camera_model = Exif.get_camera_model(exif);
                    flash = Exif.get_flash(exif);
                    focal_length = Exif.get_focal_length(exif);
                    gps_lat = Exif.get_gps_lat(exif);
                    gps_lat_ref = Exif.get_gps_lat_ref(exif);
                    gps_long = Exif.get_gps_long(exif);
                    gps_long_ref = Exif.get_gps_long_ref(exif);
                    artist = Exif.get_artist(exif);
                    copyright = Exif.get_copyright(exif);
                    software = Exif.get_software(exif);
                }
            }
        }

        public override void update_properties(Page page) {
            base.update_properties(page);

            add_line(_("Location:"), (file_path != "" && file_path != null) ? file_path : NO_VALUE);

            add_line(_("File size:"), (filesize > 0) ? 
                format_size_for_display((int64) filesize) : NO_VALUE);

            add_line(_("Original Dimensions"), (original_dim.has_area()) ?
                "%d x %d".printf(original_dim.width, original_dim.height) : NO_VALUE);

            add_line(_("Camera Make:"), (camera_make != "" && camera_make != null) ?
                camera_make : NO_VALUE);

            add_line(_("Camera Model:"), (camera_model != "" && camera_model != null) ?
                camera_model : NO_VALUE);

            add_line(_("Flash:"), (flash != "" && flash != null) ? flash : NO_VALUE);

            add_line(_("Focal Length:"), (focal_length != "" && focal_length != null) ?
                focal_length : NO_VALUE);

            add_line(_("GPS Latitude:"), (gps_lat != -1 && gps_lat_ref != "" && 
                gps_lat_ref != null) ? "%f °%s".printf(gps_lat, gps_lat_ref) : NO_VALUE);
            
            add_line(_("GPS Longitude:"), (gps_long != -1 && gps_long_ref != "" && 
                gps_long_ref != null) ? "%f °%s".printf(gps_long, gps_long_ref) : NO_VALUE);

            add_line(_("Artist:"), (artist != "" && artist != null) ? artist : NO_VALUE);

            add_line(_("Copyright:"), (copyright != "" && copyright != null) ? copyright : NO_VALUE);
    
            add_line(_("Software:"), (software != "" && software != null) ? software : NO_VALUE);

            set_text();
        }
    }

    public ExtendedPropertiesWindow() {
        add_events(Gdk.EventMask.BUTTON_PRESS_MASK | Gdk.EventMask.KEY_PRESS_MASK);
        focus_on_map = true;
        set_accept_focus(true);
        set_flags(Gtk.WidgetFlags.CAN_FOCUS);
        set_keep_above(true);
        set_title(_("Extended Information"));
        set_size_request(300,-1);
        set_position(Gtk.WindowPosition.CENTER);

        delete_event += hide_on_delete;

        properties = new ExtendedProperties();
        Gtk.Alignment alignment = new Gtk.Alignment(0.5f,0.5f,1,1);
        alignment.add(properties);
        alignment.set_padding(4, 4, 4, 4);
        add(alignment);
    }

    private override bool button_press_event(Gdk.EventButton event) {
        // LMB only
        if (event.button != 1)
            return (base.button_press_event != null) ? base.button_press_event(event) : true;
        
        begin_move_drag((int) event.button, (int) event.x_root, (int) event.y_root, event.time);
        
        return true;
    }

    private override bool key_press_event(Gdk.EventKey event) {
        // send through to AppWindow
        return AppWindow.get_instance().key_press_event(event);
    }

    public void update_properties(Page page) {
        properties.update_properties(page);
    }
}
