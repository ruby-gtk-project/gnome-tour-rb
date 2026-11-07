# Component inventory — gnome-tour-rb

Upstream: `origin/main` (Rust/gtk-rs, GResource-backed). Port: `ruby` branch,
`lib/gnome_tour_rb/`.

One section per upstream component (source file + its `.ui`, where split
across two files, counted as one unit per the `component-identification`
skill). For each: the widget tree, CSS classes, signals, actions, and the
`lib/*.rb` file it maps to on the port side, with existence noted.

## Application — `src/application.rs`, `src/main.rs` → `lib/gnome_tour_rb/application.rb`

**EXISTS.**

| Facet | Upstream | Port |
|---|---|---|
| Type | `Application(adw::Application)` | `Application` wrapping `Gtk::Application` |
| Actions | `app.quit` (accel `<Control>q`), `win.skip-tour` accel `Escape` (installed on the window class, accel set here) | `app.quit` action + both accels set in `startup` |
| Lifecycle | `startup`: none beyond parent; `activate`: raise existing window or build+present | `startup`: `Adwaita.init`, register icon search path, load stylesheet, install `quit` action, set accels; `activate`: build on first run, else raise, then present |
| Resources | Loads compiled GResource (`config::RESOURCES_FILE`), registers it | No GResource; reads `data/` directly via `Paths` — icons via `IconTheme#add_search_path`, stylesheet read and `@ASSETS@`-substituted |
| Logging | `env_logger` + `G_MESSAGES_DEBUG` compat (`src/main.rs`) | `lib/gnome_tour_rb/log.rb` — present, same compat rule |
| i18n setup | `gettextrs` `bindtextdomain`/`textdomain`, `glib::set_application_name` | `lib/gnome_tour_rb/i18n.rb` (own PO reader) + `GLib.application_name = _('Tour')` in `Application#build` |

Notes: no widget tree of its own (not a `Gtk.Widget`), so no CSS/signal rows
beyond the two actions and the `startup`/`activate` handlers noted above.
Full parity — nothing upstream does here is missing on the port.

## Window — `src/widgets/window.rs` + `data/resources/ui/window.ui` → `lib/gnome_tour_rb/window.rb`

**EXISTS.**

| Widget | × | CSS | Signals/handlers | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` (template root `Window`) | 1 | `devel` (profile == Devel only) | `constructed`: sets icon-name, devel class, welcome body | default size 960×720; port: `Adwaita::ApplicationWindow.new`, `set_default_size`, `icon_name=`, conditional `devel` class |
| `PaginatorWidget` (content) | 1 | — | — | → `Paginator` (see below), set as `win.content=` |
| `ImagePageWidget` (child of paginator) | 7 | `last-page` on the 7th only | — | → `ImagePage`, one per `PAGES` entry |

Actions installed on the window class (`win.` prefix):

| Action | Upstream handler | Port | Present |
|---|---|---|---|
| `win.start-tour` | `win.start_tour()` → `paginator.set_page(1)` | `install_actions['start-tour']` → `start_tour` → `paginator.set_page(1)` | yes |
| `win.skip-tour` | `application.quit()` | `install_actions['skip-tour']` → `application.quit` | yes |
| `win.next-page` | `paginator.try_next` else `win.close()` | `install_actions['next-page']` → `next_page` → same | yes |
| `win.previous-page` | `paginator.try_previous` else `reset_tour` (`set_page(0)`) | `install_actions['previous-page']` → `previous_page` → same | yes |

Accel: `win.skip-tour` → `Escape`, set in `Application#startup`. Present.

Welcome-page body string: `"Learn about the key features in {name} {version}."`
filled from `glib::os_info("NAME"/"VERSION")` upstream, `OsInfo.name`/`.version`
in the port (`lib/gnome_tour_rb/os_info.rb`, present — reads `/etc/os-release`).

Full parity.

## Paginator — `src/widgets/paginator.rs` + `data/resources/ui/paginator.ui` → `lib/gnome_tour_rb/paginator.rb`

**EXISTS.**

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Bin` (template root `PaginatorWidget`) | 1 | — | — | port: `Adwaita::Bin` |
| `Adw.ToolbarView` | 1 | — | — | top bar + content |
| `Gtk.HeaderBar` | 1 | — | — | `title-widget` = carousel dots |
| `Adw.CarouselIndicatorDots` | 1 | — | — | bound to carousel |
| `Gtk.Overlay` (`previous_overlay`) | 1 | — | — | `valign: center` |
| `Gtk.Button` (`previous_btn`) | 1 | `circular` | `clicked` via `action-name=win.previous-page` | tooltip "Previous" (translatable) |
| `Gtk.Button` (`next_btn`) | 1 | `circular` | `action-name=win.next-page` | tooltip "Next" |
| `Gtk.Button` (`start_btn`) | 1 | `circular`, `suggested-action` | `action-name=win.start-tour` | tooltip "Start" |
| `Adw.Carousel` | 1 | — | `notify::position` → `on_position_notify` | `scroll-params` set in code to `Adw::SpringParams(1.0, 0.5, 300.0)` |
| `Gtk.EventControllerKey` (controller, not a widget) | 1 | — | `key-pressed` → `on_key_pressed` | arrow-key nav |

Port mapping: `bin`→`Adwaita::Bin`, `toolbar_view`→`Adwaita::ToolbarView`,
`header_bar`→`Gtk::HeaderBar`, `carousel_dots`→`Adwaita::CarouselIndicatorDots`,
`overlay`→`Gtk::Overlay`, `previous_button`/`next_button`/`start_button`→
`Gtk::Button` via shared `nav_button` factory (3 call sites — 3 widgets, per
the skill's factory-counting rule), `carousel`→`Adwaita::Carousel`,
`key_controller`→`Gtk::EventControllerKey`. All signal connections present:
`notify::position` and `key-pressed` both wired in `#build`.

Behaviour: `try_next`/`try_previous`/`set_page`, direction-tracking
(`remember_direction`/`focus_button`), the three-way opacity cross-fade
(`opacities`/`apply_opacities`/`fade`), and the "next button not targetable
while settling onto the last page" rule are all transcribed
(`lib/gnome_tour_rb/paginator.rb`, matches `on_position_notify`/`try_next`/
`try_previous`/`set_page` in `src/widgets/paginator.rs`).

Full parity.

## Image page — `src/widgets/image_page.rs` + `data/resources/ui/image-page.ui` → `lib/gnome_tour_rb/image_page.rb`

**EXISTS** (as `ImagePage`, a plain class rather than upstream's
`GtkWidget` subclass with an `AdwClampLayout` — a declared, documented
divergence in `PORTING.md`; the `page` CSS class and clamp constraint are
preserved via `Adwaita::Clamp`).

| Widget | × | CSS | Notes |
|---|---:|---|---|
| Root (`ImagePageWidget` template, parent `GtkWidget` + `AdwClampLayout`) | 1 | `page` | port: `Adwaita::Clamp` carrying `page` (+ `halign/valign: fill`, `hexpand/vexpand: true`) |
| `Gtk.Box` (`container`) | 1 | — | vertical, spacing 12, centered, margins (top 12, bottom 48, start/end 12) |
| `Gtk.Picture` (`picture`) | 1 | — | `can-shrink: true`, `content-fit: contain`, bound to `resource-uri`/`asset` |
| `Gtk.Label` (`head_label`) | 1 | `title-1` | bound to `head` property; `margin-top: 36` |
| `Gtk.Label` (body, unnamed) | 1 | `body` | bound to `body` property; `lines: 2`, `wrap: true`, `margin-top: 12` |

Properties: `resource-uri`/`asset` (construct-only), `head` (construct-only),
`body` (construct, settable after construction — upstream via GObject
property notify/bind, port via `ImagePage#body=` plus an explicit
`body_label.label = text` — used once, for the welcome page's runtime body).

Full parity.

## `.ui` files — `data/resources/ui/{window,paginator,image-page}.ui`

All three folded into their owning Ruby class above (house style: no `.ui`
files in the port, declarative trees are built in code). No standalone
template or menu with no backing class — none exists upstream for this app.

## Stylesheet — `data/resources/style.css` → `data/style.css`

**EXISTS**, carried over with one divergence: upstream's `url(...)` refs are
absolute GResource paths (`/org/gnome/Tour/hand-fg.svg` etc.); the port's copy
uses an `@ASSETS@` token substituted for a `file://` URI by
`Application#stylesheet_source` (no GResource on this side). Classes/rules:
`.page:nth-child(5)` (up-down hand animation) and `.page:nth-child(6)`
(left-right hand animation), both present; the two commented-out gradient
rules for `nth-child(2)`/`nth-child(4)` are dead code upstream and correctly
not reproduced.

## GSettings schemas

**None upstream.** `gnome-tour` ships no GSettings schema (confirmed: no
`data/*.gschema.xml.in` in `git ls-tree -r --name-only origin/main`). Nothing
to port; no gap.

## GResource manifest — `data/resources.gresource.xml`

**No port equivalent by design** (`PORTING.md`: "No GResource. Artwork, icons
and the stylesheet are read from `data/`"). Every file it lists is accounted
for individually below rather than through a resource bundle:

| GResource entry | Port location | Present |
|---|---|---|
| `style.css` | `data/style.css` | yes |
| `ui/{image-page,paginator,window}.ui` | folded into `lib/gnome_tour_rb/{image_page,paginator,window}.rb` | yes (as code, not `.ui`) |
| `{welcome,overview,search,blank,workspaces,ready-to-go}.svg` | `data/assets/*.svg` | yes, all 6 present |
| `hand-fg.svg`, `updown-bg.svg`, `leftright-bg.svg` | `data/assets/*.svg` | yes, all 3 present |
| `prev-large-symbolic{,-rtl}.svg`, `next-large-symbolic{,-rtl}.svg` (aliases of `left-large-symbolic.svg`/`right-large-symbolic.svg`) | `data/icons/hicolor/...` | present as a `hicolor` icon theme dir, registered via `IconTheme#add_search_path` in `Application#register_icons` — RTL variants resolved by the icon theme rather than by alias, per `PORTING.md` |

## Desktop entry, metainfo, D-Bus service

| Upstream | Port | Present |
|---|---|---|
| `data/org.gnome.Tour.desktop.in.in` | `data/org.gnome.Tour.Rb.desktop.in` | yes, own app id suffix `.Rb` |
| `data/org.gnome.Tour.metainfo.xml.in.in` | `data/org.gnome.Tour.Rb.metainfo.xml.in` | yes |
| `data/org.gnome.Tour.service.in` | `data/org.gnome.Tour.Rb.service` | yes |
| meson `i18n.merge_file` (translates `Name=`/`<name>` etc. into both) | `scripts/merge_translations.rb`, run via `rake desktop` | yes, per `PORTING.md` |

## Keyboard shortcuts

| Shortcut | Upstream | Port |
|---|---|---|
| `<Control>q` | `app.quit` | present, `Application#build` |
| `Escape` | `win.skip-tour` | present, `Application#build` |
| `Left`/`Right` arrow (carousel, via `EventControllerKey`) | `Paginator`/`PaginatorWidget` `on_key_pressed` | present, `Paginator#on_key_pressed` |

No shortcuts dialog/window exists upstream for this app (it is a 3-window-action
greeter, not a full app), so none is expected on the port side — confirmed
absent from `git ls-tree -r --name-only origin/main` (no `shortcuts*.ui`/`.blp`).

## Dialogs, preferences, menus, empty/error states

**None exist upstream.** `gnome-tour` has no preferences dialog, no menu
model, no empty-state or error-state UI — it is a single window with one
child widget tree (paginator → 7 image pages) and no secondary surfaces.
Confirmed by the full `git ls-tree -r --name-only origin/main` listing above:
the only UI-bearing files are the three `.ui` files already covered. Nothing
missing because nothing exists to miss.

## Summary table

| Upstream file(s) | Port file | Kind | Exists |
|---|---|---|---|
| `src/application.rs`, `src/main.rs` | `lib/gnome_tour_rb/application.rb` | application class | yes |
| `src/widgets/window.rs` + `ui/window.ui` | `lib/gnome_tour_rb/window.rb` | window | yes |
| `src/widgets/paginator.rs` + `ui/paginator.ui` | `lib/gnome_tour_rb/paginator.rb` | composite widget | yes |
| `src/widgets/image_page.rs` + `ui/image-page.ui` | `lib/gnome_tour_rb/image_page.rb` | composite widget | yes |
| `src/config.rs.in` + meson `profile` option | `lib/gnome_tour_rb/config.rb` | config/build-time constants | yes |
| `src/main.rs` (env_logger setup) | `lib/gnome_tour_rb/log.rb` | logging | yes |
| `gettextrs` usage throughout | `lib/gnome_tour_rb/i18n.rb` | i18n | yes |
| `glib::os_info` calls in `window.rs` | `lib/gnome_tour_rb/os_info.rb` | OS info helper | yes |
| (no upstream equivalent — GResource replaced by disk paths) | `lib/gnome_tour_rb/paths.rb` | path helper | yes |
| `data/resources/style.css` | `data/style.css` | stylesheet | yes |
| `data/*.desktop.in.in`, `*.metainfo.xml.in.in`, `*.service.in` | `data/org.gnome.Tour.Rb.*` | packaging metadata | yes |
| `po/*.po` (65 languages incl. source strings) | `po/*.po` (65 present) | translation catalogue | yes — count matches; full `msgid`-level census is `translation-parity`'s job, not repeated here |
| (none upstream: no gschema, no shortcuts window, no preferences dialog, no menu model) | — | — | n/a — nothing to port |

## Bottom line

Every upstream user-facing component — the application, the window and its
four `win.` actions plus two accelerators, the paginator with its three
buttons/carousel/key-controller, the seven image pages, the stylesheet
animations, the icon set, and the desktop/metainfo/service packaging — has a
corresponding, already-written file in `lib/` or `data/` on the `ruby`
branch, with matching widgets, CSS classes, signals and actions as far as
component identification can establish by reading. This is a component
inventory, not a component-parity proof (string/count-level verification is
`component-parity`'s and `translation-parity`'s job): the one soft spot is
`translation-parity`'s open flag that the port's PO reader does not
implement `msgctxt`/plural forms, which costs nothing against today's
23-message catalogue but should be re-checked if upstream's catalogue ever
grows a `msgctxt`-qualified string or a plural.
