# Component parity — gnome-tour-rb

| | |
|---|---|
| Upstream | `main` @ `7ed8211cc07ceeea50e412d8168c5761caee9bea` |
| Port | `ruby` @ `8afabc3029af86bb46c051160fa7509655b1da82` |
| Units with parity | 4 / 4 UI units, 5 / 5 support units |

Every row below was checked by diffing the actual upstream source
(`git show origin/main:<path>`) against the actual port file, plus one live
run of the driven test suite (Step 5, `ruby-gtk-testing`-style), not from the
scan alone.

## Unit: application — `src/application.rs` → `lib/gnome_tour_rb/application.rb`

| Item | Up | Port | Verdict |
|---|---|---|---|
| App type | `Adw.Application` | `Gtk::Application` + explicit `Adwaita.init` | correspondence — `AdwApplication` is broken in ruby-gnome; `PORTING.md` names the defect |
| `app.quit` action | 1 | 1 | parity |
| Accel `app.quit` → `<Control>q` | yes | yes (driven: `drive_tour.rb` step 1 asserts `get_accels_for_action('app.quit') == ['<Control>q']`) | parity |
| Accel `win.skip-tour` → `Escape` | yes | yes (driven, same step) | parity |
| `activate` re-presents existing window | yes | yes (`case a.active_window when nil then main_window.build`) | parity |
| `resource-base-path` | `/org/gnome/Tour` | `/org/gnome/Tour` (unused no-op, no GResource) | parity |
| Icon registration / stylesheet load | — (GResource) | `register_icons`, `load_stylesheet` | correspondence — the mechanism that replaces GResource lookup, not a new feature |

Driven: `win.skip-tour` calls `application.quit` (`quit_test.rb`, 3 checks,
all pass — "win.skip-tour was reached", "...ends the main loop", "...did not
need the watchdog"). `app.quit` likewise (3 more checks, same file).

Verdict: **parity.**

## Unit: window — `src/widgets/window.rs` + `data/resources/ui/window.ui` → `lib/gnome_tour_rb/window.rb`

| Widget | Up × | Port × | CSS | Signals/Actions | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.ApplicationWindow` | 1 | 1 | `devel` (devel builds only) | — | — | parity |
| `PaginatorWidget` (content) | 1 | 1 | — | — | — | parity |
| `ImagePageWidget` (repeater) | 7 | 7 | `last-page` on 7th only, both sides | — | ✓ (see per-page text below) | parity |

Actions: `win.start-tour`, `win.skip-tour`, `win.next-page`,
`win.previous-page` — 4 upstream, 4 in the port
(`window.rb#install_actions`), same semantics (`next-page` closes the window
on `nil`, `previous-page` resets to page 0 on `nil`). Driven: "four win.
actions" check passes in `drive_tour.rb`.

Per-page text (msgid, both sides byte-identical — see
`translation-parity.md` for the full census):

| Page | Head | Body |
|---|---|---|
| 1 welcome | "Let's Begin" | runtime-filled, `_('Learn about the key features in {name} {version}.')` |
| 2 overview | "Get an Overview" | "The overview shows all your apps and windows. Press the Super (Windows) key to open it." |
| 3 search | "Powerful Search" | "To search, just start typing in the overview. You can use search to launch apps, find files, perform calculations, and more." |
| 4 workspaces | "Stay Organized With Workspaces" | "Organize your windows by moving them into different workspaces. This can be done by dragging them in the overview." |
| 5 swipe up/down | "Swipe Up and Down" | "To quickly open the overview with a touchpad, swipe up with three fingers." |
| 6 swipe left/right | "Swipe Left and Right" | "To move between workspaces, swipe three fingers horizontally." |
| 7 closing | "That's It!" | "To get more advice and tips, see the Help app." |

All 7 verified against `window.ui`'s 7 `<child>` blocks and the port's
`PAGES` constant — identical strings, identical order, identical
`last-page` placement.

Driven (`drive_tour.rb`): 7-page carousel, welcome heading/body, closing
heading, `last-page` present on page 7 and absent on page 1 — all assert
`ok`.

Verdict: **parity.**

## Unit: paginator — `src/widgets/paginator.rs` + `paginator.ui` → `lib/gnome_tour_rb/paginator.rb`

| Widget | Up × | Port × | CSS | Signals | Verdict |
|---|---:|---:|---|---|---|
| `Adw.Bin` (root) | 1 | 1 | — | — | parity |
| `Adw.ToolbarView` | 1 | 1 | — | — | parity |
| `Gtk.HeaderBar` | 1 | 1 | — | — | parity |
| `Adw.CarouselIndicatorDots` | 1 | 1 | — | — | parity |
| `Gtk.Overlay` | 1 | 1 | — (`valign: center`) | — | parity |
| `Gtk.Button` ×3 (prev/next/start) | 3 | 3 (1 factory, 3 call sites) | `circular` ×3, `suggested-action` on start | — | parity — shared-factory correspondence, not a gap (3 call sites checked individually) |
| `Adw.Carousel` | 1 | 1 | — | `notify::position` → `on_position_notify` | parity |
| `Gtk.EventControllerKey` (controller) | 1 | 1 | — | `key-pressed` → `on_key_pressed` | parity |

`SpringParams(1.0, 0.5, 300.0)` matches literally. `on_position_notify`'s
three-way opacity split (`0.0...1.0`, `..forelast_page`, else) and the
`can_target` rules for `start_btn`/`next_btn` are a line-for-line transcription
— verified by reading both implementations side by side.

Driven: button visibility/targetability and fade state checked at every
page transition in `drive_tour.rb` (steps 2, 3, 9, 18, 19) — "start
visible", "start is targetable", "next hidden", "start faded out", "next is
no longer targetable", "start button is back", "previous button is hidden
again" all pass. The `Left`/`Right` key controller is driven directly
(`paginator.call.on_key_pressed(Gdk::Keyval::KEY_Left/KEY_Right)`, steps 10
and 11) and asserted to move the carousel.

Verdict: **parity.**

## Unit: image page — `src/widgets/image_page.rs` + `image-page.ui` → `lib/gnome_tour_rb/image_page.rb`

| Widget | Up × | Port × | CSS | Verdict |
|---|---:|---:|---|---|
| template root / `Adwaita::Clamp` | 1 | 1 | `page` (+ `last-page` on page 7) | parity — `AdwClampLayout` layout manager vs. `Adwaita::Clamp` is the documented, located correspondence |
| `Gtk.Box` (container) | 1 | 1 | — | parity |
| `Gtk.Picture` | 1 | 1 | — | parity |
| `Gtk.Label` (head) | 1 | 1 | `title-1` | parity |
| `Gtk.Label` (body) | 1 | 1 | `body` | parity |

Properties: `resource-uri`/`head` construct-only, `body` writable post-
construction — reproduced (`ImagePage#body=`). Margins (12/12/12/48 on the
container, 36 on the head label, 12 on the body label), `lines: 2`/`wrap` on
the body label, `can-shrink`/`content-fit: contain` on the picture — all
identical values, confirmed by direct read of both files.

Verdict: **parity.**

## Support units (no widget tree, but real behaviour upstream owns)

| Unit | Upstream | Port | Verdict |
|---|---|---|---|
| i18n bootstrap | `gettextrs` `setlocale`/`bindtextdomain`/`textdomain`, `glib::set_application_name(&gettext("Tour"))` | no gettext binding exists in ruby-gnome, so `I18n` reads `po/*.po` directly; `GLib.application_name = _('Tour')` reproduces the one observable effect (`main.rs` vs `application.rb`) | correspondence — documented in `PORTING.md`, confirmed by reading both |
| `os_info` | `glib::os_info("NAME"/"VERSION")`, fallback `"GNOME"`/`""` | `OsInfo` reads `/etc/os-release` directly with the same fallbacks (no Ruby binding exists) | parity |
| logging | `env_logger` + `G_MESSAGES_DEBUG` compatibility shim, 3 startup lines | `Log` module, same env vars, same 3 lines (`Config.app_id`/`version`/`pkgdatadir`) | parity |
| build profile | `config.rs.in` + meson `-Dprofile=development` | `Config` module driven by `GNOME_TOUR_RB_PROFILE`; same suffix (`Devel`), same devel CSS class, same commit-SHA version stamp | parity — driven in `drive_tour.rb` step 18 ("devel style class", "devel icon name", "the default build does not") |
| resource paths | GResource bundle (`resources.gresource.xml`) | `Paths` module reading from `data/` | correspondence — the mechanism GResource provides, documented |

## CSS stylesheet (Step 4)

```
diff <(git show origin/main:data/resources/style.css) data/style.css
```

Only two pairs of lines differ, both `@ASSETS@` vs. a GResource path —
exactly the documented, build-time-token correspondence. Every class
`.page`, `:nth-child(3/5/6)`, `up-and-down`/`left-and-right` keyframes is
present verbatim on both sides. The commented-out gradient rules for pages 2
and 4 are commented out identically. No gap.

## Screenshots (Step 4, visual)

`drive_tour.rb` produces `tmp/shots/01-welcome.png` through
`05-back-at-welcome.png` plus `locale_test.rb`'s `06-german.png`, rendered
headlessly off the real widget tree (Step 4/5 of the skill). Confirmed
present after this session's `rake test` run.

## Overall verdict

**4/4 UI units and 5/5 support units have full four-axis parity.** No widget,
CSS class, signal, action or string was found missing, extra, or diverging in
either direction. All 43 driven checks in `test/drive_tour.rb` plus the
11 in `test/locale_test.rb` pass against this exact set of assertions
(re-run this session: `nix develop --command xvfb-run -a rake test`, full
log captured, "DRIVE OK" both times).

One scope note the earlier `component-inventory.md` already states and this
pass confirms: upstream has **no** GSettings schema, preferences dialog,
about dialog, shortcuts window, menu model or primary menu — the whole app
is one window, one carousel, seven pages, four `win.` actions and one
`app.quit`. There is no empty state and no error state in the upstream app
to check parity against (a tour has nothing to be empty or fail); this is a
fact about the upstream app, not an omission in the port.
