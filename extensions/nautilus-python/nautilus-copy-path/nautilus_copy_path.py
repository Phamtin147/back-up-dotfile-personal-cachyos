import os
import json
import shlex
import subprocess
from urllib.parse import urlparse, unquote
from translation import Translation
from gi import require_version
import gi

require_version('Gtk', '4.0')
require_version('Nautilus', '4.1')
from gi.repository import Nautilus, GObject, Gtk, Gdk, GLib


class NautilusCopyPath(GObject.Object, Nautilus.MenuProvider):
    def _window_added(self, application, window):
        for key, shortcut_str in self.config.get("shortcuts", {}).items():
            if shortcut_str:
                action = Gtk.CallbackAction.new(self._shortcuts_handler)
                shortcut = Gtk.Shortcut.new(Gtk.ShortcutTrigger.parse_string(shortcut_str), action)
                shortcut.set_arguments(GLib.Variant.new_string(key))
                window.add_shortcut(shortcut)

    def _window_removed(self, application, window):
        if window:
            window_id = window.get_id()
            if window_id in self.selected_files:
                del self.selected_files[window_id]

    def __init__(self):
        super().__init__()
        self.selected_files = {}

        self.config = {
            "items": {
                "path": True,
                "uri": False,
                "name": True,
                "content": False
            },
            "selections": {
                "clipboard": True,
                "primary": True
            },
            "shortcuts": {
                "path": "<Ctrl><Shift>C",
                "uri": "",
                "name": "<Ctrl><Shift>D",
                "content": ""
            },
            "language": "auto",
            "separator": "\n",
            "escape_value_items": False,
            "escape_value": False,
            "name_ignore_extension": False
        }

        self.allow_copy_content = [
            "application/x-shellscript",
            "application/json",
        ]

        cfg_path = os.path.join(os.path.dirname(__file__), "config.json")
        if os.path.exists(cfg_path):
            with open(cfg_path) as json_file:
                try:
                    self.config.update(json.load(json_file))
                except Exception:
                    pass

        if self.config.get("language"):
            Translation.select_language(self.config["language"])

        app = Gtk.Application.get_default()
        if app:
            app.connect("window-added", self._window_added)
            app.connect("window-removed", self._window_removed)

    def _shortcuts_handler(self, window, key):
        action = GLib.Variant.get_string(key)
        window_id = window.get_id() if window else None

        action_function = {
            'path': self._copy_paths,
            'uri': self._copy_uris,
            'name': self._copy_names,
            'content': self._copy_content
        }.get(action)

        files = self.selected_files.get(window_id, [])
        if files and action_function:
            action_function(None, files)
            return True
        return False

    def get_file_items(self, *args):
        app = Gtk.Application.get_default()
        window = app.get_active_window() if app else None
        files = args[-1]

        if window:
            self.selected_files[window.get_id()] = files

        return self._create_menu_items(files, "File")

    def get_background_items(self, *args):
        file = args[-1]
        return self._create_menu_items([file], "Background")

    def _create_menu_items(self, files, group):
        plural = len(files) > 1
        config_items = self.config.get("items", {})
        active_items = []

        if config_items.get("path", True):
            item_path = Nautilus.MenuItem(
                name="NautilusCopyPath::CopyPath" + group,
                label=Translation.t("copy_paths" if plural else "copy_path"),
            )
            item_path.connect("activate", self._copy_paths, files)
            active_items.append(item_path)

        if config_items.get("uri", False):
            item_uri = Nautilus.MenuItem(
                name="NautilusCopyPath::CopyUri" + group,
                label=Translation.t("copy_uris" if plural else "copy_uri"),
            )
            item_uri.connect("activate", self._copy_uris, files)
            active_items.append(item_uri)

        if config_items.get("name", True):
            item_name = Nautilus.MenuItem(
                name="NautilusCopyPath::CopyName" + group,
                label=Translation.t("copy_names" if plural else "copy_name"),
            )
            item_name.connect("activate", self._copy_names, files)
            active_items.append(item_name)

        if config_items.get("content", False):
            filtered_files = []
            for file in files:
                file_type = file.get_mime_type()
                if file_type in self.allow_copy_content or file_type.startswith("text/"):
                    filtered_files.append(file)

            if len(filtered_files) > 0:
                item_content = Nautilus.MenuItem(
                    name="NautilusCopyPath::CopyContent" + group,
                    label=Translation.t("copy_content"),
                )
                item_content.connect("activate", self._copy_content, filtered_files)
                active_items.append(item_content)

        return active_items

    def _copy_paths(self, menu, files):
        def _uri_to_path(file):
            if hasattr(file, 'get_location'):
                loc = file.get_location()
                if loc and loc.get_path():
                    return loc.get_path()
            raw_uri = file.get_activation_uri() or file.get_uri()
            p = urlparse(raw_uri)
            return os.path.abspath(os.path.join(p.netloc, unquote(p.path)))

        self._copy_value(list(map(_uri_to_path, files)))

    def _copy_uris(self, menu, files):
        self._copy_value(list(map(lambda f: f.get_activation_uri() or f.get_uri(), files)))

    def _copy_names(self, menu, files):
        def _name(file):
            raw_uri = file.get_activation_uri() or file.get_uri()
            path = unquote(os.path.basename(raw_uri))
            if self.config.get("name_ignore_extension", False):
                path = os.path.splitext(path)[0]
            return path

        self._copy_value(list(map(_name, files)))

    def _copy_content(self, menu, files):
        content = []
        for file in files:
            file_type = file.get_mime_type()
            if file_type in self.allow_copy_content or file_type.startswith("text/"):
                if hasattr(file, 'get_location'):
                    loc = file.get_location()
                    p = loc.get_path() if loc else None
                else:
                    p = None
                if not p:
                    raw_uri = file.get_activation_uri() or file.get_uri()
                    pu = urlparse(raw_uri)
                    p = os.path.abspath(os.path.join(pu.netloc, unquote(pu.path)))
                try:
                    with open(p, 'r') as _file:
                        content.append(_file.read())
                except Exception:
                    pass

        self._copy_value(content)

    def _copy_value(self, value):
        if not value:
            return

        if self.config.get("escape_value_items", False):
            value = list(map(lambda x: shlex.quote(x), value))

        new_value = self.config.get("separator", "\n").join(value)

        if self.config.get("escape_value", False):
            new_value = shlex.quote(new_value)

        display = Gdk.Display.get_default()
        if display:
            if self.config.get("selections", {}).get("clipboard", True):
                cb = display.get_clipboard()
                if cb:
                    cb.set(new_value)

            if self.config.get("selections", {}).get("primary", True):
                pcb = display.get_primary_clipboard()
                if pcb:
                    pcb.set(new_value)

        # Wayland clipboard sync
        try:
            subprocess.run(["wl-copy", "--", new_value], check=False)
            subprocess.run(["wl-copy", "-p", "--", new_value], check=False)
        except Exception:
            pass
