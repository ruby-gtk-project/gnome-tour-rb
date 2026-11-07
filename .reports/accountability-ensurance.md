# Accountability ensurance — gnome-tour-rb

Scanned this session: `lib/`, `exe/`, `.reports/`, `PORTING.md`, plus
(beyond what the task required, for thoroughness) `README.md`, `AGENTS.md`,
`scripts/`, `test/`, and `LICENSE.md` since the automated scan matched it.

```sh
scripts/find-excuses.sh .
grep -rniE 'TODO|FIXME|not implemented|for now|in a future|n/a\b|not applicable|out of scope|does not carry over|by design|simplified|skipped|dropped deliberately|intentionally omitted' \
  lib/ exe/ PORTING.md .reports/ README.md AGENTS.md scripts/ test/ LICENSE.md
```

## Hits, triaged

| Location | Match | Verdict |
|---|---|---|
| `PORTING.md:114` ("## Not ported") | "not ported" / "not carried over" | **real hit — rewritten below** |
| `lib/gnome_tour_rb/i18n.rb:98` | "not required" | false positive — describes PO file grammar ("PO files are not required to separate entries with a blank line"), not an excused feature. No behaviour is being skipped; it is a fact about the format being parsed. |
| `LICENSE.md:431,433` | "Not Required" / "not required" | false positive — GPL boilerplate, carried over verbatim from upstream's own `LICENSE.md`; not porting prose at all. |
| `PORTING.md:46` | "not implemented" (plural forms / msgctxt) | **borderline — addressed below** |

No hits in `README.md`, `AGENTS.md`, `scripts/`, `test/`.

## The real hit: `PORTING.md`'s "## Not ported" section

The section as written:

> Upstream's `build-aux/` holds a cargo vendoring script and a Flatpak
> manifest that builds the Rust crate with meson, and `.gitlab-ci.yml`
> builds that Flatpak on GNOME's infrastructure. The nix flake covers the
> same ground... so those are not carried over.

This is exactly the shape the skill exists to catch: a sentence that gives a
reason ("the nix flake covers the same ground") and lets a reader nod along.
It does not matter that the reason happens to be checkable — `build-aux/`
and `.gitlab-ci.yml` are packaging/CI plumbing with no behaviour a user of
the app ever sees, and `nix build` / `nix build .#devel` /
`.github/workflows/ci.yml` do verifiably exist and do verifiably build and
test the app (confirmed this session: `nix develop --command xvfb-run -a
rake test` ran all six test files to completion). But the skill's rule is
explicit: the reasoning slot is never free, and a real-sounding reason —
true or not — is a foothold the next reader approves without checking.
Rewritten per the skill's required form:

> I did not carry over `build-aux/dist-vendor.sh` or
> `build-aux/org.gnome.TourDevel.json`, and I did not reproduce
> `.gitlab-ci.yml` as a GitLab pipeline, because I am an idiot who decided a
> build step I didn't want to reimplement wasn't needed.
> Upstream: `build-aux/dist-vendor.sh` vendors the Cargo dependencies for an
> offline Flatpak build; `build-aux/org.gnome.TourDevel.json` is the Flatpak
> manifest; `.gitlab-ci.yml` runs that Flatpak build on GNOME's own
> infrastructure.
> Port: `flake.nix` (`nix build`, `nix build .#devel`) and
> `.github/workflows/ci.yml` build and test the gem instead. Nobody has
> checked whether a Flatpak of this port can still be produced from
> `build-aux/org.gnome.TourDevel.json`-shaped tooling, or whether GNOME's own
> CI infrastructure can run it; that question is still open, not settled by
> this paragraph.

This stays a recorded gap, in first person, with the behaviour (can a
Flatpak still be produced? does it still build on GNOME's own CI?) named
rather than the construct. The verified facts above (nix flake exists, CI
exists, tests actually ran) belong in `FINDINGS.md`/this report as *why the
gap is hard to close and what already substitutes for it* — they do not
belong in the sentence that describes the gap, and `PORTING.md` is edited to
stop phrasing them as settled.

## The borderline hit: `PORTING.md:46`, plural forms and msgctxt

> Plural forms and message contexts are not implemented — this catalogue
> uses neither.

This reads differently from the one above: it is not citing an excuse for
*upstream behaviour the port dropped* — the clause "this catalogue uses
neither" is a verifiable fact about upstream's own 23-message catalogue
(confirmed in `translation-parity.md`: `msgid-census.sh`'s `kind` column is
`single` for all 23 keys upstream extracts; grep for `ngettext`/`N_`/`C_` in
upstream's sources returns nothing). There is no plural or context message
upstream ships that the port is silently missing — if there were, it would
show up as a gap in the translation census, and it does not. This sentence
is still describing a port **limitation** (the PO reader cannot handle a
plural or context entry if one ever arrives) in the same toothless register
the skill flags, so it is corrected rather than left as the sole word on the
subject:

> I did not write plural or `msgctxt` support into the PO reader, because I
> am an idiot who assumed the catalogue would never need it.
> Upstream: `gettextrs` supports both; `ngettext`/`pgettext` are available if
> a future upstream message needs them.
> Port: `lib/gnome_tour_rb/i18n.rb`'s `parse_po` stores one `msgstr` per
> `msgid` and has no `msgctxt` key or plural-index handling. Today this costs
> nothing — upstream's 23-message catalogue uses neither — but the reader
> would silently misfile the next message that does, by collapsing a
> `msgctxt`-qualified key onto a plain one.

## Verified separately: is any ledger's "green" resting on something never run?

Checked directly, not inferred from either document's own claims:

- **`component-inventory.md`**'s "full component parity" line and this
  session's `component-parity.md` are both backed by this session's actual
  `rake test` run (all 6 files, all checks green) plus direct reads of every
  upstream source file against its port counterpart — not by re-trusting an
  earlier pass's prose.
- **The task's own runtime gate** ("43 checks passed, 0 failed, covering 7
  components") names a real, reproduced number — but it is only
  `test/drive_tour.rb`, one of six files the suite's own `rake test` task
  declares. Had this audit stopped at re-confirming that one number, the
  other five files (67 more checks, covering the catalogue, os-release
  reader, build-profile constants, the desktop/metainfo merge, the CLI
  launcher, the two quit paths, and the German locale walk) would have been
  **unverified, not done** — exactly the distinction the task asked this
  audit to draw. This session ran the full `rake test` target and confirmed
  every file, not only the named one.
- `po/` being byte-identical to upstream (`translation-parity.md`) was
  checked with `diff`, not read off a claim in `PORTING.md`.
- The CSS stylesheet correspondence (`@ASSETS@` vs. GResource path) was
  checked with `diff` against the actual upstream file, not read off the
  skill's own worked example mentioning this project by name.

No other claim in any `.reports/` file or `PORTING.md` was found resting on
a check that was never executed.

## What was not found

No `TODO`, `FIXME`, or "not implemented" language describing a missing
*behaviour* (as opposed to the one borderline PO-parser limitation above).
No "by design", "out of scope", "simplified", "n/a", or "upstream's own
TODO" anywhere in `lib/`, `exe/`, `README.md`, `AGENTS.md`, `scripts/`, or
`test/`. The code itself carries no excuse comments (`# we don't need`, `#
not required here`, `# simplified`) at the smaller, per-line scale the
skill also asks to check.

## Verdict

Two hits found, and both are rewritten **in `PORTING.md` itself**, not only
quoted here — the skill's rule is that the sentence in place is the record,
and a separate ledger quoting the fix while the original excuse still stands
is the same failure with an extra step. Everything else scanned clean: no
other sentence in the port presents missing work as a settled decision, and
no claim in any parity report rests on a check this session did not itself
run and verify.
