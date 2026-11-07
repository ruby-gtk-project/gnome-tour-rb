# Component inventory — gnome-tour-rb vs upstream (origin/main)

Surveyed on 2026-11-07, from upstream `origin/main` (gtk-rs/Rust) against the
`ruby` branch's `lib/`. GNOME Tour is a small app — one application, one
window, one composite widget (the paginator) and one repeated widget (the
image page, instantiated 7 times) — so the whole app is one unit.

Upstream has no GSettings schema and no shortcuts window; the only
declarative UI is the three `.blp`-equivalent `.ui` files under
`data/resources/ui/`. `data/resources/style.css` is loaded verbatim by the
port (see `lib/gnome_tour_rb/application.rb#load_stylesheet`), not
reimplemented, so its page backgrounds/animations are not a separate
component — they ride along with the stylesheet file itself.

## Summary table

| Upstream file(s) | Port file | Kind | Exists? |
|---|---|---|---|
| `src/application.rs` | `lib/gnome_tour_rb/application.rb` | app class (actions, accels, startup) | Yes |
| `src/main.rs` | `lib/gnome_tour_rb.rb` (+ `exe/gnome-tour-rb`) | entry point | Yes |
| `src/widgets/window.rs` + `data/resources/ui/window.ui` | `lib/gnome_tour_rb/window.rb` | `Adw.ApplicationWindow` subclass | Yes |
| `src/widgets/paginator.rs` + `data/resources/ui/paginator.ui` | `lib/gnome_tour_rb/paginator.rb` | `Adw.Bin` subclass (composite widget) | Yes |
| `src/widgets/image_page.rs` + `data/resources/ui/image-page.ui` | `lib/gnome_tour_rb/image_page.rb` | `Gtk.Widget` subclass (repeated widget, ×7) | Yes |
| `src/config.rs.in` | `lib/gnome_tour_rb/config.rb` | build-time constants → runtime module | Yes |
| (glib::os_info, no Ruby binding) | `lib/gnome_tour_rb/os_info.rb` | os-release reader | Yes |
| (gettext, no Ruby binding) | `lib/gnome_tour_rb/i18n.rb` | PO catalogue reader | Yes |
| (env_logger) | `lib/gnome_tour_rb/log.rb` | startup banner / logging | Yes |
| (GResource path layout) | `lib/gnome_tour_rb/paths.rb` | on-disk asset/po paths | Yes |
| `data/resources/style.css` | `data/style.css` (loaded as-is, not ported to Ruby) | stylesheet | Yes |
| `data/org.gnome.Tour.desktop.in.in` | — | desktop entry (no actions, not a widget) | N/A |
| `data/org.gnome.Tour.metainfo.xml.in.in` | — | AppStream metadata (no widget) | N/A |
| `po/*.po` | `po/*.po` (read directly by `i18n.rb`) | translation catalogue | Present, needs separate translation-parity pass |

**Every component upstream defines already has a corresponding, built-out
file on `ruby`.** This survey found no missing component file. (A
line-by-line widget/CSS/signal parity check against each file is the job of
the `component-parity` skill, not this inventory — see Blockers below for
what stood out while reading.)

---

## `src/application.rs`, `src/main.rs` — the application object

**Port: `lib/gnome_tour_rb/application.rb`, `lib/gnome_tour_rb.rb`**

| Component | Notes |
|---|---|
| `Adw.Application` subclass | Ported as `Gtk::Application` + `Adwaita.init` (no `Adwaita::Application` binding used); one window, re-activate raises it |
| Action `app.quit` | `Gio::SimpleAction` installed on startup — present |
| Accel `<Control>q` → `app.quit` | present |
| Accel `Escape` → `win.skip-tour` | present |
| GResource load / icon registration | replaced by `Gtk::IconTheme#add_search_path` against `data/icons` — present |
| Stylesheet load | `Gtk::CssProvider` loaded from `data/style.css` with `@ASSETS@` substituted to a `file://` URI — present |

Status: **present**, same actions/accels/behaviour.

## `src/widgets/window.rs` + `data/resources/ui/window.ui` — the tour window

**Port: `lib/gnome_tour_rb/window.rb`**

| Widget | × | CSS | Signals/Actions | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | `devel` (devel profile only) | — | default size 960×720, icon-name = app id |
| `PaginatorWidget` (own type) | 1 | — | hosts the 4 `win.*` actions | set as window content |
| `ImagePageWidget` (own type) | 7 | `last-page` (7th page only) | — | repeater over the 7-entry page list; welcome page's body is set after construction from `os_info` |
| action `win.start-tour` | | | → `paginator.set_page(1)` | present |
| action `win.skip-tour` | | | → `application.quit` | present |
| action `win.next-page` | | | → `paginator.try_next`, closes window on `nil` | present |
| action `win.previous-page` | | | → `paginator.try_previous`, resets tour on `nil` | present |

Status: **present**. Port builds the 7 pages from a `PAGES` constant array
(a repeater) rather than literal `.ui` children — same 7 pages, same text,
same `last-page` class on the 7th, same welcome-body substitution.

## `src/widgets/paginator.rs` + `data/resources/ui/paginator.ui` — the carousel chrome

**Port: `lib/gnome_tour_rb/paginator.rb`**

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Bin` (template root) | 1 | — | — | top-level |
| `Adw.ToolbarView` | 1 | — | — | top bar + content |
| `Gtk.HeaderBar` | 1 | — | — | title-widget = dots |
| `Adw.CarouselIndicatorDots` | 1 | — | — | bound to carousel |
| `Gtk.Overlay` | 1 | — | — | `valign: center` |
| `Gtk.Button` (previous) | 1 | `circular` | `action-name: win.previous-page` | tooltip "Previous" |
| `Gtk.Button` (next) | 1 | `circular` | `action-name: win.next-page` | tooltip "Next" |
| `Gtk.Button` (start) | 1 | `circular`, `suggested-action` | `action-name: win.start-tour` | tooltip "Start" |
| `Adw.Carousel` | 1 | — | `notify::position` → `on_position_notify` | hexpand/vexpand, custom `SpringParams(1.0, 0.5, 300.0)` |
| `Gtk.EventControllerKey` | 1 (controller) | — | `key-pressed` → `on_key_pressed` | Left/Right arrow navigation |

Status: **present**. All 9 widgets, both CSS classes, both signal
connections, and the 3 `action-name` bindings are reproduced; the port uses
`signal_connect`/manual action dispatch in place of GtkBuilder
`action-name`/`<signal>` binding (ruby-gnome has no `action-name` property
binding equivalent used here — worth a second look under `component-parity`
to confirm the buttons' `action-name` is wired, not just their click
handlers).

## `src/widgets/image_page.rs` + `data/resources/ui/image-page.ui` — one tour page

**Port: `lib/gnome_tour_rb/image_page.rb`**

| Widget | × | CSS | Notes |
|---|---:|---|---|
| `Gtk.Widget` w/ `Adw.ClampLayout` (template root) | 1 | `page` | upstream uses a custom widget + layout manager; port uses `Adwaita::Clamp` directly as the equivalent container — same constraint, one widget instead of two |
| `Gtk.Box` (container) | 1 | — | vertical, spacing 12, centered, margins 12/48/12/12 |
| `Gtk.Picture` | 1 | — | `can-shrink`, `content-fit: contain`, resource/file source |
| `Gtk.Label` (head) | 1 | `title-1` | bound to `head` property |
| `Gtk.Label` (body) | 1 | `body` | bound to `body` property, `lines: 2`, `wrap: true` |

Dynamic CSS: `last-page` class, applied only to the 7th instantiation (from
`Window::PAGES`), reproduced as `style_class:` constructor arg.

Status: **present**. Note the one structural difference called out above
(custom-widget-with-layout-manager vs. `Adwaita::Clamp` container) — same
visual/layout result, flagged for `component-parity` to confirm rather than
assume.

## Non-widget components

- **`data/org.gnome.Tour.desktop.in.in`** — no desktop actions, nothing to port as a widget.
- **`data/org.gnome.Tour.metainfo.xml.in.in`** — AppStream description/screenshots; informational only, no window reads it.
- **`po/*.po`** (77 locale files + `LINGUAS`/`POTFILES.in`) — read directly by `lib/gnome_tour_rb/i18n.rb` at runtime; **translation-parity** (not this skill) should confirm the 10-string catalogue the port's `I18n` module expects actually matches what each `.po` ships.
- **No GSettings schema**, **no shortcuts window**, **no About dialog**, **no preferences** anywhere in this app upstream.

## Blockers / open questions for the next pass

- None block starting app code — every upstream file already has a built-out
  port file. The two items flagged above (`action-name` button wiring in
  `paginator.rb`, and the `Adw.Clamp`-vs-custom-layout-manager substitution in
  `image_page.rb`) are candidates for the `component-parity` skill to verify
  signal-for-signal and widget-for-widget; they are not missing components.
- Translation parity (do the 77 `po/*.po` files actually satisfy
  `i18n.rb`'s PO parser for every string `_()` is called with) is explicitly
  out of scope here and belongs to a `translation-parity` pass.
