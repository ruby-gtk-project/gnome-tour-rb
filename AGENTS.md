# gnome-tour — Ruby port

The Ruby GTK4 / Libadwaita port of GNOME Tour. The upstream Rust
implementation lives on the fork's other branches (`main` and the `gnome-*`
release branches); this branch is the port.

## Skills — use them

Two skills are installed in `.claude/skills/`. They are not optional reading.

- **ruby-gtk** — the house style for Ruby GTK4/Libadwaita: the declarative
  memoized-widget pattern, Adwaita binding quirks, worked examples. Load it
  before writing or reviewing ANY Ruby GTK code, including single widgets, and
  before planning a port. The bindings are quirky enough that code written from
  memory is unreliable.
- **ruby-gtk-testing** — run the app headlessly and drive its UI: click through
  dialogs, assert widget state, capture screenshots. Use it before claiming any
  GTK change works. `ruby -c` and a successful `require` prove nothing about a
  UI.

## Running and testing

`direnv allow` (or `nix develop`) gets Ruby, GTK4, Libadwaita, librsvg and the
bundled gems from `gemset.nix`. Regenerate that file with `bundix -l` whenever
`Gemfile.lock` moves; nix only sees git-tracked files, so `git add` it first.

- `bin/gnome-tour-rb` runs the app.
- `rake` runs the checks and rubocop. `rake test` alone runs
  `test/catalogue_test.rb` (no display needed) and `test/drive_tour.rb`, which
  builds the real window headlessly and writes screenshots to `tmp/shots`.

`PORTING.md` records how this port maps onto the Rust original and the
ruby-gnome defects found while writing it — read it before changing the
paginator or the stylesheet loading.


## Style

`.rubocop.yml` plus the custom cops in `cops/` are enforced: no `return`, no
modifier `if`, no conditional assignment, `tap` where it applies, and fixed
multi-line argument/hash layout. Run `bundle exec rubocop` before committing.
