# gnome-tour-rb — upstream component inventory

Upstream ref: `origin/main` (GNOME Tour, Rust/gtk-rs). Port branch: `ruby`.

Upstream is a gtk-rs app with three `GtkBuilder` templates. Every component is
split across a `.rs` subclass and a `.ui` tree, so the rows below are the union
of both halves (see `component-identification`, "the component is the set of
files"). There is **no** GSettings schema, no preferences dialog, no about
dialog, no shortcuts window, no menu model and no primary menu anywhere in
upstream — the whole app is one window, one carousel, seven pages and four
`win.` actions.

## Unit map

| Upstream file(s) | Port file | Kind | Exists |
|---|---|---|---|
| `src/main.rs` | `lib/gnome_tour_rb.rb`, `exe/gnome-tour-rb` | entry point | yes |
| `src/main.rs` (gettext/locale block) | `lib/gnome_tour_rb/i18n.rb` | i18n bootstrap | yes |
| `src/main.rs` (`env_logger`, `log::info!`) | `lib/gnome_tour_rb/log.rb` | logging | yes |
| `src/application.rs` | `lib/gnome_tour_rb/application.rb` | application | yes |
| `src/widgets/window.rs` + `data/resources/ui/window.ui` | `lib/gnome_tour_rb/window.rb` | window | yes |
| `src/widgets/paginator.rs` + `data/resources/ui/paginator.ui` | `lib/gnome_tour_rb/paginator.rb` | composite widget | yes |
| `src/widgets/image_page.rs` + `data/resources/ui/image-page.ui` | `lib/gnome_tour_rb/image_page.rb` | page widget | yes |
| `src/config.rs.in` + `src/meson.build` | `lib/gnome_tour_rb/config.rb` | build constants | yes |
| `glib::os_info` (no Ruby binding) | `lib/gnome_tour_rb/os_info.rb` | support | yes |
| `data/resources.gresource.xml` | `lib/gnome_tour_rb/paths.rb` | resource lookup | yes |
| `data/resources/style.css` | `data/style.css` | stylesheet | yes |
| `data/resources/assets/*.svg` (9) | `data/assets/*.svg` (9) | artwork | yes |
| `data/resources/{left,right}-large-symbolic.svg` | `data/icons/hicolor/scalable/actions/{prev,next}-large-symbolic{,-rtl}.svg` | icons | yes |
| `data/icons/org.gnome.Tour*.svg` | `data/icons/hicolor/scalable/apps/org.gnome.Tour.Rb*.svg` | app icons | yes |
| `data/org.gnome.Tour.desktop.in.in` | `data/org.gnome.Tour.Rb.desktop.in` | desktop entry | yes |
| `data/org.gnome.Tour.metainfo.xml.in.in` | `data/org.gnome.Tour.Rb.metainfo.xml.in` | appstream | yes |
| `data/org.gnome.Tour.service.in` | `data/org.gnome.Tour.Rb.service` | D-Bus activation | yes |
| `po/` (63 locales + `LINGUAS`) | `po/` (63 locales, `LINGUAS` identical) | catalogue | yes |

## src/application.rs — the application object

| Widget / object | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Application` | 1 | — | `activate`, `startup` | port uses `Gtk::Application` + explicit `Adwaita.init` (`Adwaita::Application` is broken in the bindings) |

Actions: `app.quit`. Accelerators: `app.quit` → `<Control>q`;
`win.skip-tour` → `Escape`. `resource-base-path` `/org/gnome/Tour`.
`activate` presents the existing window rather than building a second one.

Port additions with no upstream counterpart, forced by having no GResource:
`register_icons` (`Gtk::IconTheme` search path) and `load_stylesheet`
(`Gtk::CssProvider` at `PRIORITY_APPLICATION`, with `@ASSETS@` substituted to
absolute `file://` URIs).

## src/widgets/window.rs + data/resources/ui/window.ui — the tour window

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | `devel` (only when `PROFILE == "Devel"`) | — | 960×720, `icon-name` = app id |
| `PaginatorWidget` | 1 | — | — | the window's `content`; app-defined template |
| `ImagePageWidget` | 7 | `last-page` (7th only) | — | repeater over the seven page definitions |

Actions installed: `win.start-tour` (→ page 1), `win.skip-tour` (→ app quit),
`win.next-page` (→ `try_next`, closes the window on `None`),
`win.previous-page` (→ `try_previous`, resets to page 0 on `None`).

The seven pages, in carousel order — asset, head, body:

1. `welcome.svg` — "Let's Begin" — body set at runtime from
   `"Learn about the key features in {name} {version}."` with `glib::os_info`
   `NAME`/`VERSION` (fallbacks `GNOME` / empty)
2. `overview.svg` — "Get an Overview"
3. `search.svg` — "Powerful Search"
4. `workspaces.svg` — "Stay Organized With Workspaces"
5. `blank.svg` — "Swipe Up and Down" (background supplied by `.page:nth-child(5)`)
6. `blank.svg` — "Swipe Left and Right" (`.page:nth-child(6)`)
7. `ready-to-go.svg` — "That's It!" — `last-page`

Port: the pages live in a frozen `PAGES` constant and are mapped to
`ImagePage` instances, so the seven are a repeater rather than seven literals.

## src/widgets/paginator.rs + data/resources/ui/paginator.ui — carousel and navigation

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Bin` | 1 | — | — | template root; carries the key controller |
| `Adw.ToolbarView` | 1 | — | — | header bar on top, overlay as content |
| `Gtk.HeaderBar` | 1 | — | — | `title-widget` is the dot indicator |
| `Adw.CarouselIndicatorDots` | 1 | — | — | bound to the carousel |
| `Gtk.Overlay` (`previous_overlay`) | 1 | — | — | `valign: center` |
| `Gtk.Button` (`previous_btn`) | 1 | `circular` | — | `prev-large-symbolic`, tooltip "Previous", `win.previous-page`, `halign: start`, `margin-start: 12` |
| `Gtk.Button` (`next_btn`) | 1 | `circular` | — | `next-large-symbolic`, tooltip "Next", `win.next-page`, `halign: end`, `margin-end: 12` |
| `Gtk.Button` (`start_btn`) | 1 | `circular`, `suggested-action` | — | `next-large-symbolic`, tooltip "Start", `win.start-tour`, `halign: end`, `margin-end: 12` |
| `Adw.Carousel` | 1 | — | `notify::position` → `on_position_notify` | `hexpand`/`vexpand`, `SpringParams(1.0, 0.5, 300.0)` |
| `Gtk.EventControllerKey` | 1 (controller) | — | `key-pressed` → `on_key_pressed` | `Right` → next, `Left` → previous, always propagates |

Repeaters: the carousel's pages (7, inserted by the window via `add_page`).

Behaviour that is part of the component, not decoration:

- `on_position_notify` cross-fades the three buttons against the carousel's
  *fractional* position, so they track a swipe: in `0.0..1.0` the start button
  fades out while previous and next fade in; up to `n_pages - 2` previous and
  next are opaque and start is hidden; past that next fades out toward the
  last page.
- `start_btn.can_target` is `opacity_next < EPSILON` and `next_btn.can_target`
  is `opacity_next > 0 && position <= forelast`, so a half-faded next button
  cannot be clicked past the end.
- `set_page` grabs focus on `previous_btn` when walking backward, on
  `start_btn` on page 0, on `next_btn` otherwise.

Port note: the three buttons come from one private `nav_button` factory, so a
scan reports `Gtk.Button 1` against upstream's 3 and `css circular 1` against
3. Three call sites, three buttons — not a gap.

## src/widgets/image_page.rs + data/resources/ui/image-page.ui — one tour page

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| template root (`Gtk.Widget` + `Adw.ClampLayout`) | 1 | `page` | — | `hexpand`/`vexpand`, `halign`/`valign: fill` |
| `Gtk.Box` (`container`) | 1 | — | — | vertical, spacing 12, centred, `vexpand`, margins 12/12/12/48 |
| `Gtk.Picture` (`picture`) | 1 | — | — | `can-shrink`, `content-fit: contain`, set from `resource-uri` |
| `Gtk.Label` (`head_label`) | 1 | `title-1` | — | bound to the `head` property, `margin-top: 36` |
| `Gtk.Label` (body) | 1 | `body` | — | bound to the `body` property, `lines: 2`, `wrap`, `margin-top: 12` |

Properties: `resource-uri` (construct-only), `head` (construct-only), `body`
(construct, writable — the window sets the welcome page's after construction).

Port note: the port uses `Adwaita::Clamp` as the root instead of a
`Gtk::Widget` subclass with an `AdwClampLayout` layout manager — the same
constraint in one widget, and it is what carries the `page` class. The
`last-page` class is added through an optional `style_class:` argument.
Because `.page:nth-child(N)` selects on position among the carousel's
children, the `page` class must stay on the widget the carousel holds; it does.

## data/resources/style.css — the stylesheet

Classes defined: `page` with `:nth-child(3)` (empty rule), `:nth-child(5)`
(`up-and-down` keyframes, `hand-fg.svg` over `updown-bg.svg`) and
`:nth-child(6)` (`left-and-right` keyframes, `hand-fg.svg` over
`leftright-bg.svg`). Keyframes: `up-and-down`, `left-and-right`. Two gradient
rules for pages 2 and 4 are commented out upstream and are commented out in
the port too.

Classes applied by the app but defined by libadwaita, not here: `title-1`,
`body`, `circular`, `suggested-action`, `devel`. Applied but never defined
anywhere: `last-page` (upstream sets it for the benefit of outside styling).

## Gaps

The port has full component parity with upstream, in both directions: every
upstream unit has a port file, and there are no port files without an upstream
counterpart. The original scaffold (`lib/gnome_tour.rb`,
`lib/gnome_tour/application.rb`, `exe/gnome-tour`) has been deleted, so the app
has one entry point — `exe/gnome-tour-rb` → `lib/gnome_tour_rb.rb`.
