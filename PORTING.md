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
| `src/main.rs` — logging, i18n, resource registration | `lib/gnome_tour_rb/log.rb` and `Application#build` |
| `src/config.rs.in` + the meson `profile` option | `lib/gnome_tour_rb/config.rb`, driven by `GNOME_TOUR_RB_PROFILE` |
| `gettext` | `lib/gnome_tour_rb/i18n.rb` |
| `glib::os_info` | `lib/gnome_tour_rb/os_info.rb` |
| `i18n.merge_file` in `data/meson.build` | `scripts/merge_translations.rb` |
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

The same reader backs `scripts/merge_translations.rb`, which stands in for
meson's `i18n.merge_file`: it substitutes the application id into
`data/*.desktop.in` and `data/*.metainfo.xml.in` and folds every translation
back in as `Name[lang]=` lines and `xml:lang` siblings, so the app is localised
in the shell and the software centre as well as in its own window. The nix
build runs it and then validates the result with `desktop-file-validate` and
`appstreamcli validate`, the way upstream's meson tests do; `rake validate`
does the same locally.

**The build profile is an environment variable.** Upstream picks it at
configure time with `-Dprofile=development`; there is no configure step here,
so `Config` reads `GNOME_TOUR_RB_PROFILE`. It does the same three things
upstream's does: suffixes the application id (`org.gnome.Tour.RbDevel`),
stamps the short commit SHA into the version, and puts the `devel` style class
on the window. `nix build .#devel` produces that build, icon and all.

**Logging is stdlib `Logger`.** Upstream uses `env_logger` plus a shim that
turns on debug for its own module when `G_MESSAGES_DEBUG` would not have
dropped it. `Log` keeps that behaviour: silent by default, debug when
`G_MESSAGES_DEBUG` names `gnome_tour_rb` or `all`, and `GNOME_TOUR_RB_LOG` sets
a level outright. The three startup lines upstream logs are logged here too.

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

**Destroying an `Adwaita::ApplicationWindow` that was never presented
segfaults** — not an exception, a `Gdk-CRITICAL` about a null surface followed
by SIGSEGV inside the introspection loader. `test/drive_tour.rb` builds its
throwaway devel window and simply leaves it for the application to take down.

**`Gtk::Application#run` needs the program name at the head of the argv it is
given.** Handed a bare `ARGV` — or the empty list the house entry-point
convention suggests — GApplication sees no arguments at all and runs normally
whatever it was asked to do, so `--help` hangs and the D-Bus service file's
`--gapplication-service` silently launches a full window instead of a service.
And its return value is the exit status, which the launcher has to pass to
`exit` itself, the way upstream's `main` returns the `glib::ExitCode`.

**Data files must be read as UTF-8 explicitly.** Ruby decodes with the
locale's encoding, which is US-ASCII under a bare `LANG=C` — as in a nix build
sandbox — and every `po/*.po` file then raises `invalid byte sequence in
US-ASCII`. The catalogue, os-release and stylesheet readers all pass
`encoding: 'UTF-8'`.

**CSS background images need librsvg.** GTK loads CSS `url()` images through
gdk-pixbuf, so without librsvg's SVG loader the swipe pages' animated
backgrounds parse without error and then paint nothing — while the same SVGs
render fine in a `GtkPicture`, which does not go through gdk-pixbuf. The flake
puts librsvg in the shell and sets `GDK_PIXBUF_MODULE_FILE`.

## Not ported

Upstream's `build-aux/` holds a cargo vendoring script and a Flatpak manifest
that builds the Rust crate with meson, and `.gitlab-ci.yml` builds that Flatpak
on GNOME's infrastructure. The nix flake covers the same ground —
`nix build` for the installable app, `nix build .#devel` for the development
one — and `.github/workflows/ci.yml` runs it here along with the checks, so
those are not carried over. Everything else upstream ships has an equivalent:

| Upstream | Here |
| --- | --- |
| `Cargo.toml`, `Cargo.lock` | `Gemfile`, `Gemfile.lock`, `gemset.nix` |
| `meson.build`, `meson_options.txt`, `src/meson.build`, `data/meson.build` | `flake.nix`, `Rakefile`, `scripts/merge_translations.rb` |
| `rustfmt.toml` | `.rubocop.yml` and `cops/` |
| `hooks/pre-commit.hook` (rustfmt) | `hooks/pre-commit.hook` (rubocop), installed by `rake hooks` |
| `data/resources.gresource.xml` | nothing — the files are read from `data/` |
| `.editorconfig`, `NEWS`, `LICENSE.md`, the doap | carried over as-is |

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

Once `settle` is doing the waiting, the driver's own tick is dead time: at the
default half-second interval the walk took about ninety seconds and started
tripping the 120-second watchdog. A 100 ms interval and a long watchdog bring
it to about thirteen.

The carousel's spring approaches a page asymptotically, so a check for
"the start button is hidden" fails on a hair of leftover opacity. Assert on
`opacity`, which is what the cross-fade actually sets.
