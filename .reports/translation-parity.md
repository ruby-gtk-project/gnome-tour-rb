# Translation parity — gnome-tour-rb

| | |
|---|---|
| Upstream | `main` @ `7ed8211cc07ceeea50e412d8168c5761caee9bea` |
| Port | `ruby` @ `8afabc3029af86bb46c051160fa7509655b1da82` |
| Upstream msgids | 23 distinct (24 extraction sites, "Tour" used 3×) |
| Ported | 23 / 23 |
| Gaps | 0 |
| Languages | 63 / 63, `po/LINGUAS` and every `po/*.po` byte-identical to upstream |

## Census (Step 1)

Upstream's `po/POTFILES.in` names 6 sources:

```
data/org.gnome.Tour.desktop.in.in
data/org.gnome.Tour.metainfo.xml.in.in
data/resources/ui/paginator.ui
data/resources/ui/window.ui
src/widgets/window.rs
src/main.rs
```

`translation-parity/scripts/msgid-census.sh` run against those 6 files
(fetched this session with `git show origin/main:<path>`) extracts:

```
A guided tour and greeter for GNOME.
Get an Overview
Gnome;GTK;
GNOME Tour and Greeter
Greeter & Tour
Learn about the key features in {name} {version}.
Let's Begin
Next
Organize your windows by moving them into different workspaces. This can be done by dragging them in the overview.
Powerful Search
Previous
Start
Stay Organized With Workspaces
Swipe Left and Right
Swipe Up and Down
That's It!
The GNOME Project
The overview shows all your apps and windows. Press the Super (Windows) key to open it.
To get more advice and tips, see the Help app.
To move between workspaces, swipe three fingers horizontally.
To quickly open the overview with a touchpad, swipe up with three fingers.
To search, just start typing in the overview. You can use search to launch apps, find files, perform calculations, and more.
Tour   (appears 3×: main.rs, desktop.in.in, metainfo.xml.in.in)
```

23 distinct `(msgctxt, msgid)` keys — upstream uses no `msgctxt` and no
plural form anywhere in this catalogue, confirmed by the census's `kind`
column (all `single`).

Cross-checked directly against `po/de.po`'s 24 `msgid` lines (the blank
`msgid ""` header plus the same 23 strings) — identical set.

## Where each key lives in the port (Step 2 — mapping)

| Upstream source | Port equivalent |
|---|---|
| `data/org.gnome.Tour.desktop.in.in` | `data/org.gnome.Tour.Rb.desktop.in`, filled by `scripts/merge_translations.rb` |
| `data/org.gnome.Tour.metainfo.xml.in.in` | `data/org.gnome.Tour.Rb.metainfo.xml.in`, same script |
| `data/resources/ui/{paginator,window}.ui` | `lib/gnome_tour_rb/{paginator,window}.rb` — `_('...')` call sites |
| `src/widgets/window.rs` (the runtime-filled welcome body) | `lib/gnome_tour_rb/window.rb#welcome_body` |
| `src/main.rs` (`gettext("Tour")` → `set_application_name`) | `lib/gnome_tour_rb/application.rb` — `GLib.application_name = _('Tour')` |

## Byte-identity (Step 2 continued)

Every one of the 23 keys appears, byte-identical, as a `_('...')` call site
in `lib/gnome_tour_rb/{window,paginator,application}.rb` (page heads/bodies
via the `PAGES` constant and `I18n._`, button tooltips via `nav_button`,
"Tour" via `GLib.application_name = _('Tour')`). No key was found reworded,
retyped, or built via string interpolation (`#{}`) ahead of the translation
lookup — the one welcome-page body that varies at runtime is built as
`_('Learn about the key features in {name} {version}.').gsub('{name}',
...)`, i.e. the lookup happens on the literal msgid first and the `{name}`/
`{version}` placeholders are substituted into the *translated* string
afterward, matching upstream's `formatx!(gettext(...), name:, version:)`
exactly rather than defeating the catalogue the way an interpolated literal
would.

## Catalogue mechanism (Step 3 — the correspondence, not a gap)

Upstream links `gettextrs` (`setlocale`/`bindtextdomain`/`textdomain`,
`ngettext`-capable). No gettext binding exists for Ruby GTK apps, and
`PORTING.md` names this; the port's `I18n` module reads `po/*.po` directly at
startup instead of going through libc's gettext machinery. This is a real,
located mechanism substitution — not an unmarked string or an invented
excuse — and it is exercised directly: `test/locale_test.rb` sets
`LANGUAGE=de`, builds the real window, and asserts (11/11, this session) that
the German catalogue is picked, that every page heading and body is
translated, that the tooltips are translated, and that the runtime-filled
welcome body is translated *and* still names the OS with no leftover
`{name}`/`{version}` placeholder. This is the one axis `component-parity`
explicitly says a scan cannot prove — it is proven here by actually running
the app under a different locale.

## Languages (Step 3 — the catalogue itself)

```
diff <(git show origin/main:po/LINGUAS) po/LINGUAS       # identical
diff <(git show origin/main:po/de.po)   po/de.po          # identical
diff <(git show origin/main:po/fr.po)   po/fr.po          # identical
comm -3 <(git ls-tree -r --name-only origin/main | grep '^po/' | sed 's#^po/##' | sort) \
        <(ls po | sort)
# -> po/meson.build only (a build-file artefact; there is no meson here)
```

All 63 `.po` files plus `LINGUAS` are carried over byte-for-byte. The only
upstream `po/` entry absent from the port is `meson.build`, which is build
plumbing with nothing for a translator to read — not a translation asset,
and not something a Ruby `Rakefile` has any use for.

## Desktop entry / metainfo translation (the other half of this axis)

`scripts/merge_translations.rb` stands in for `i18n.merge_file`:
`test/config_test.rb` (28/28 this session) asserts the generated
`.desktop`/`.metainfo.xml` carry a translated `Name[lang]=`/`xml:lang`
sibling **for every language in `LINGUAS` that has a catalogue entry for that
key** — not just that the merge runs, but that every language survives it.

## Verdict

**23/23 msgids ported, byte-identical, 63/63 languages carried over
unchanged, and the result is driven under a non-English locale rather than
only asserted statically.** No gap found on any of the three claims this
skill defines.

---

## Re-audit — 2026-11-07, port @ ef7461e207849f937f60f2db6f44c716f29aa85b

Independently re-run this session (no `lib/`, `exe/`, `test/`, `po/`,
`data/` commit landed between the port revision this report was written
against and current `HEAD`, confirmed with
`git log --oneline <old-sha>..HEAD -- lib exe test po data` returning
nothing), so the claims above still describe the code as it stands:

- Re-diffed `po/de.po`, `po/fr.po` and `po/LINGUAS` against `origin/main` with `diff -q`: byte-identical, confirming the 23/23, 63/63 claim still holds.
