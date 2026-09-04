# Porting notes

What the Rust original does, what this port does instead, and the handful of
ruby-gnome defects found on the way.

## Structure

| Upstream (Rust) | Here (Ruby) |
| --- | --- |
| `src/application.rs` — `AdwApplication` subclass | `lib/gnome_tour_rb/application.rb` — a `Gtk::Application` with `startup`/`activate` handlers |
| `src/widgets/window.rs` + `ui/window.ui` | `lib/gnome_tour_rb/window.rb`, with the seven pages as a `PAGES` constant |
| `src/widgets/paginator.rs` + `ui/paginator.ui` | `lib/gnome_tour_rb/paginator.rb` |
| `src/widgets/image_page.rs` + `ui/image-page.ui` | `lib/gnome_tour_rb/image_page.rb` |
| `gettext` | `lib/gnome_tour_rb/i18n.rb` |
| `glib::os_info` | `lib/gnome_tour_rb/os_info.rb` |
| GResource bundle | plain files under `data/` |

The page-fade arithmetic in `Paginator#opacities` is a direct transcription of
upstream's `on_position_notify`, including the rule that the next button stops
being targetable while the carousel settles onto the last page.

## Deliberate divergences

**No GObject subclassing, no composite templates.** The house style is
memoized widget methods assembled in `build`, so `ImagePageWidget` becomes a
plain Ruby class whose `build` returns the root widget. Upstream's
`ImagePageWidget` is a `GtkWidget` with an `AdwClampLayout` layout manager;
an `AdwClamp` is that same constraint in one widget, and it carries the `page`
style class the stylesheet selects on by position.

**No GResource.** Artwork, icons and the stylesheet are read from `data/`.
Two consequences:

- The arrow icons are installed as a `hicolor` theme under `data/icons` and
  registered with `Gtk::IconTheme#add_search_path`, which keeps the automatic
  RTL variants working.
- `data/style.css` refers to the swipe artwork through an `@ASSETS@` token,
  substituted for an absolute `file://` URI when the provider is loaded.

**No gettext.** There is no gettext binding in the Ruby GTK stack, and the
gettext gem would add a dependency plus a msgfmt build step. The catalogue is
ten strings, so `I18n` reads the shipped `po/*.po` files directly. Plural
forms and message contexts are not implemented — this catalogue uses neither.

## ruby-gnome defects and environment traps

**`Adwaita.init` is not called for you.** `AdwApplication` is still broken in
the bindings, so the application object has to be a `Gtk::Application` — and
that means nothing initialises libadwaita. Without an explicit `Adwaita.init`
in `startup`, the app runs and renders, but libadwaita's stylesheet is never
loaded: `title-1`, `circular` and `suggested-action` all silently do nothing,
and the window ignores the desktop's colour scheme. Nothing warns.

**`GLib.os_info` is not bound.** `lib/gnome_tour_rb/os_info.rb` reads
`/etc/os-release` the way the C function does.

**`Gtk::IconTheme.default` and `Gtk::Picture.new_for_filename` do not exist.**
Use `Gtk::IconTheme.get_for_display(Gdk::Display.default)` and
`Gtk::Picture.new` with `filename=`.

**`Gio::ActionMap#list_actions` is missing**; `has_action?` works.
`Gtk::Application` exposes `get_accels_for_action`, not `accels_for_action`.

**CSS background images need librsvg.** GTK loads CSS `url()` images through
gdk-pixbuf, so without librsvg's SVG loader the swipe pages' animated
backgrounds parse without error and then paint nothing — while the same SVGs
render fine in a `GtkPicture`, which does not go through gdk-pixbuf. The flake
puts librsvg in the shell and sets `GDK_PIXBUF_MODULE_FILE`.

## Testing traps

`current_page` only advances when the carousel reports its new position, so a
test cannot activate `win.next-page` twice in a row and expect to be two pages
along. `test/drive_tour.rb` pumps the main loop until the carousel has arrived
(`settle`) rather than assuming one tick of the driver is enough — the swipe
pages' infinite CSS animations slow software-rendered frames enough that it
often is not.

Turning animations off with `gtk_enable_animations = false` makes the
assertions instant, but it also stops scheduling frames, so the screenshots
come back showing a stale layout. Not worth it.

The carousel's spring approaches a page asymptotically, so a check for
"the start button is hidden" fails on a hair of leftover opacity. Assert on
`opacity`, which is what the cross-fade actually sets.
