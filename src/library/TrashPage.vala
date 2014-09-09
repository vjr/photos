/* Copyright 2010-2013 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

public class TrashPage : CheckerboardPage {
    public const string NAME = _ ("Trash");

    private class TrashView : Thumbnail {
        public TrashView (MediaSource source) {
            base (source);

            assert (source.is_trashed ());
        }
    }

    private class TrashSearchViewFilter : DefaultSearchViewFilter {
        public override uint get_criteria () {
            return SearchFilterCriteria.TEXT | SearchFilterCriteria.FLAG |
                   SearchFilterCriteria.MEDIA | SearchFilterCriteria.RATING;
        }
    }

    private TrashSearchViewFilter search_filter = new TrashSearchViewFilter ();
    private MediaViewTracker tracker;

    public TrashPage () {
        base (NAME);

        init_item_context_menu ("/TrashContextMenu");
        init_page_sidebar_menu ("/TrashPageMenu");
        init_page_context_menu ("/TrashViewMenu");
        init_toolbar ("/TrashToolbar");

        tracker = new MediaViewTracker (get_view ());

        // monitor trashcans and initialize view with all items in them
        LibraryPhoto.global.trashcan_contents_altered.connect (on_trashcan_contents_altered);
        Video.global.trashcan_contents_altered.connect (on_trashcan_contents_altered);
        on_trashcan_contents_altered (LibraryPhoto.global.get_trashcan_contents (), null);
        on_trashcan_contents_altered (Video.global.get_trashcan_contents (), null);
    }

    public override Gtk.Toolbar get_toolbar () {
        if (toolbar == null) {
            base.get_toolbar ();
            var app = AppWindow.get_instance () as LibraryWindow;

            // separator to force slider to right side of toolbar
            Gtk.SeparatorToolItem separator = new Gtk.SeparatorToolItem ();
            separator.set_expand (true);
            separator.set_draw (false);
            toolbar.insert (separator, -1);

            Gtk.SeparatorToolItem drawn_separator = new Gtk.SeparatorToolItem ();
            drawn_separator.set_expand (false);
            drawn_separator.set_draw (true);

            toolbar.insert (drawn_separator, -1);

            var restore_button = new Gtk.Button ();
            restore_button.clicked.connect (on_restore);
            add_toolbutton_for_action ("Restore", restore_button);

            var delete_button = new Gtk.Button ();
            delete_button.clicked.connect (on_delete);
            add_toolbutton_for_action ("Delete", delete_button);

            var empty_trash_btn = new Gtk.Button ();
            empty_trash_btn.clicked.connect (app.on_empty_trash);
            add_toolbutton_for_action ("CommonEmptyTrash", empty_trash_btn);
            empty_trash_btn.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);

            //  show metadata sidebar button
            show_sidebar_button = MediaPage.create_sidebar_button ();
            show_sidebar_button.clicked.connect (on_show_sidebar);
            toolbar.insert (show_sidebar_button, -1);
            update_sidebar_action (!app.is_metadata_sidebar_visible ());
        }
        return toolbar;
    }

    // Puts a normal Gtk.Button in a Toolbutton in order to set relief style
    // to get around the ToolBars style control over it's children
    private void add_toolbutton_for_action (string action_name, Gtk.Button wrap_btn) {
        var action = get_action (action_name);
        var tool_item = action.create_tool_item () as Gtk.ToolItem;

        foreach (var child in tool_item.get_children ())
            tool_item.remove (child);

        wrap_btn.margin_left = wrap_btn.margin_right = 2;
        wrap_btn.label = action.get_label ();
        wrap_btn.use_underline = true;
        wrap_btn.tooltip_text = action.tooltip;
        
        tool_item.add (wrap_btn);
        toolbar.insert (tool_item, -1);
    }

    protected override void init_collect_ui_filenames (Gee.List<string> ui_filenames) {
        base.init_collect_ui_filenames (ui_filenames);

        ui_filenames.add ("trash.ui");
    }

    protected override Gtk.ActionEntry[] init_collect_action_entries () {
        Gtk.ActionEntry[] actions = base.init_collect_action_entries ();

        Gtk.ActionEntry delete_action = { "Delete", null, TRANSLATABLE, "Delete",
                                          TRANSLATABLE, on_delete
                                        };
        delete_action.label = Resources.DELETE_PHOTOS_MENU;
        delete_action.tooltip = Resources.DELETE_FROM_TRASH_TOOLTIP;
        actions += delete_action;

        Gtk.ActionEntry restore = { "Restore", null, TRANSLATABLE, "Restore", TRANSLATABLE,
                                    on_restore
                                  };
        restore.label = Resources.RESTORE_PHOTOS_MENU;
        restore.tooltip = Resources.RESTORE_PHOTOS_TOOLTIP;
        actions += restore;

        return actions;
    }

    public override Core.ViewTracker? get_view_tracker () {
        return tracker;
    }

    protected override void update_actions (int selected_count, int count) {
        bool has_selected = selected_count > 0;

        set_action_sensitive ("Delete", has_selected);
        set_action_important ("Delete", true);
        set_action_sensitive ("Restore", has_selected);
        set_action_important ("Restore", true);
        set_common_action_important ("CommonEmptyTrash", true);

        base.update_actions (selected_count, count);
    }

    private void on_trashcan_contents_altered (Gee.Collection<MediaSource>? added,
            Gee.Collection<MediaSource>? removed) {
        if (added != null) {
            foreach (MediaSource source in added)
                get_view ().add (new TrashView (source));
        }

        if (removed != null) {
            Marker marker = get_view ().start_marking ();
            foreach (MediaSource source in removed)
                marker.mark (get_view ().get_view_for_source (source));
            get_view ().remove_marked (marker);
        }
    }

    private void on_restore () {
        if (get_view ().get_selected_count () == 0)
            return;

        get_command_manager ().execute (new TrashUntrashPhotosCommand (
                                            (Gee.Collection<LibraryPhoto>) get_view ().get_selected_sources (), false));
    }

    protected override string get_view_empty_message () {
        (get_container () as LibraryWindow).toggle_welcome_page (true, "", _ ("Trash is empty"));
        return _ ("Trash is empty");
    }

    private void on_delete () {
        remove_from_app ((Gee.Collection<MediaSource>) get_view ().get_selected_sources (), _ ("Delete"),
                         ngettext ("Deleting a Photo", "Deleting Photos", get_view().get_selected_count ()), true);
    }

    public override SearchViewFilter get_search_view_filter () {
        return search_filter;
    }

    private void on_show_sidebar () {
        var app = AppWindow.get_instance () as LibraryWindow;
        app.set_metadata_sidebar_visible (!app.is_metadata_sidebar_visible ());
        update_sidebar_action (!app.is_metadata_sidebar_visible ());
    }
}