# Component identification — gnome-tour-rb

| | |
|---|---|
| Upstream | `main` @ `7ed8211cc07ceeea50e412d8168c5761caee9bea` |
| Port | `ruby` @ `8afabc3029af86bb46c051160fa7509655b1da82` |

This re-runs the `component-identification` skill against the existing
`.reports/component-inventory.md` (written by an earlier pass) to confirm it
is still accurate, rather than writing a second, divergent inventory. Every
row below was checked by reading both sides, not by re-trusting the earlier
file.

## Step 1 — declarative UI, upstream side

```
data/resources/ui/image-page.ui
data/resources/ui/paginator.ui
data/resources/ui/window.ui
```

Three `<template>` roots: `ImagePageWidget`/`GtkWidget`, `PaginatorWidget`/
`AdwBin`, `Window`/`AdwApplicationWindow`. These are the unit list, confirmed
against `src/widgets/mod.rs` and `src/main.rs`.

## Step 2 — the port side (no `.ui`/`.blp` files, by house style)

```
lib/gnome_tour_rb.rb                 - require graph / entry point
lib/gnome_tour_rb/application.rb     - src/application.rs
lib/gnome_tour_rb/window.rb          - src/widgets/window.rs + window.ui
lib/gnome_tour_rb/paginator.rb       - src/widgets/paginator.rs + paginator.ui
lib/gnome_tour_rb/image_page.rb      - src/widgets/image_page.rs + image-page.ui
lib/gnome_tour_rb/config.rb          - src/config.rs.in
lib/gnome_tour_rb/i18n.rb            - gettext (no Ruby binding)
lib/gnome_tour_rb/os_info.rb         - glib::os_info (no Ruby binding)
lib/gnome_tour_rb/log.rb             - src/main.rs (env_logger block)
lib/gnome_tour_rb/paths.rb           - data/resources.gresource.xml (no GResource)
lib/gnome/tour/rb/version.rb         - gem version shim, no upstream counterpart
exe/gnome-tour-rb                    - src/main.rs (entry point)
```

10 port files against upstream's 3 `.rs`/`.ui` pairs + `main.rs` + `config.rs.in`
— the extra files (`i18n.rb`, `os_info.rb`, `log.rb`, `paths.rb`) exist because
Ruby has no gettext/`glib::os_info`/GResource binding, each noted in
`PORTING.md`'s structure table and confirmed by reading `src/main.rs` and
`src/config.rs.in` directly.

## Widget-by-widget re-verification

### `src/application.rs` → `lib/gnome_tour_rb/application.rb`

- `Adw.Application` → `Gtk::Application` + explicit `Adwaita.init` in
  `startup` (ruby-gnome defect, documented). Confirmed by reading both files
  side by side: `app.quit` action, `app.quit` → `<Control>q`,
  `win.skip-tour` → `Escape`, `activate` re-presents the existing window
  rather than building a second — all present, same accelerators, same
  literal strings (`git show origin/main:src/application.rs` vs
  `lib/gnome_tour_rb/application.rb`).
- `resource-base-path` is set on both sides; it is a harmless no-op in the
  port (no GResource to resolve against), not a missing behaviour.
- Port-only additions `register_icons` / `load_stylesheet` exist because
  there is no GResource; they are the mechanism upstream's GResource bundle
  supplies, not new components.

### `src/widgets/window.rs` + `window.ui` → `lib/gnome_tour_rb/window.rb`

- `Adw.ApplicationWindow` 1×, `devel` CSS class gated on `PROFILE == "Devel"`,
  960×720, `icon-name` = app id — all present (`window.rb#window`).
- 4 actions installed (`start-tour`, `skip-tour`, `next-page`,
  `previous-page`) with identical semantics, confirmed against
  `klass.install_action` call sites in `window.rs`.
- 7 `ImagePageWidget` instances via the `PAGES` constant (a repeater per
  `component-identification` Step 4 — one definition, 7 instantiations,
  matching upstream's 7 literal `<child>` blocks in `window.ui`).
- `last-page` class present only on the 7th page (`style_class:` on the last
  `PAGES` entry) — matches `window.ui`'s `<style><class name="last-page"/>`
  on the 7th `<child>` only.
- Welcome body set at runtime from `OsInfo.name`/`OsInfo.version`, matching
  `glib::os_info("NAME")`/`("VERSION")` with the same fallbacks (`"GNOME"`,
  `""`).

### `src/widgets/paginator.rs` + `paginator.ui` → `lib/gnome_tour_rb/paginator.rb`

- `Adw.Bin` → `Adwaita::Bin` (1), `Adw.ToolbarView` (1), `Gtk.HeaderBar` (1),
  `Adw.CarouselIndicatorDots` (1), `Gtk.Overlay` (1, `valign: center`),
  `Adw.Carousel` (1, `SpringParams(1.0, 0.5, 300.0)`),
  `Gtk.EventControllerKey` (1 controller).
- Three `Gtk.Button`s from one `nav_button` factory — three call sites
  (`previous_button`, `next_button`, `start_button`), each with the same
  icon name, tooltip msgid, action name, halign/margin and CSS classes as
  the matching `<object>` in `paginator.ui`. Confirmed call-site by call-site,
  per the "shared factory" rule in the skill — not struck as a gap.
- `on_position_notify`'s opacity/can-target arithmetic is a line-for-line
  match of `on_position_notify` in `paginator.rs` (same thresholds:
  `0.0...1.0`, `forelast_page`, `Float::EPSILON`).
- `on_key_pressed` (`Right`/`Left` → next/previous, always returns
  propagate/false) matches.

### `src/widgets/image_page.rs` + `image-page.ui` → `lib/gnome_tour_rb/image_page.rb`

- Template root (`Adw.ClampLayout` upstream) → `Adwaita::Clamp` (documented,
  equivalent-constraint correspondence, not a gap — it is what carries the
  `page` class both sides select on by position).
- `Gtk.Box` (container, vertical, spacing 12, centred, margins 12/12/12/48),
  `Gtk.Picture` (`can-shrink`, `content-fit: contain`), head `Gtk.Label`
  (`title-1`, margin-top 36), body `Gtk.Label` (`body`, `lines: 2`, `wrap`,
  margin-top 12) — all present with identical property values.
- `resource-uri`/`head` construct-only, `body` constructed then rewritable —
  reproduced as `picture.filename=`/`head` set at `new`, `body=` a public
  writer the welcome page uses post-construction.

### Support units with no upstream widget counterpart

`i18n.rb`, `os_info.rb`, `log.rb`, `paths.rb`, `config.rb` are read
end-to-end against `src/main.rs`, `glib::os_info`, `env_logger`,
`data/resources.gresource.xml` and `src/config.rs.in` respectively in
`PORTING.md`'s "Structure" table and in this session's direct reads; each
reproduces the behaviour its upstream counterpart has (see
`component-parity.md`, "Support units" section, for the line-by-line check).

## Verdict

The existing `.reports/component-inventory.md` is accurate: every upstream
file maps to a named port file, every widget type, CSS class, signal and
action in the three `.ui` templates has a located counterpart in the port,
and there are no port-side widgets without an upstream original. No new gap
was found at the identification stage; see `component-parity.md` for the
four-axis check this inventory feeds.
