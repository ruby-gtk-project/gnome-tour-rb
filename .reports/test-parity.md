# Test parity — gnome-tour-rb

| | |
|---|---|
| Upstream | `main` @ `7ed8211cc07ceeea50e412d8168c5761caee9bea` |
| Port | `ruby` @ `8afabc3029af86bb46c051160fa7509655b1da82` |
| Upstream tests | 0 |
| Ported | 0 |
| Gaps | 0 |
| Test command | `nix develop --command xvfb-run -a rake test` |

Upstream has no test suite (verified this session:
`git ls-tree -r --name-only origin/main \| grep -iE 'test\|spec'` returns
nothing; `meson.build` has no `test(...)` target; there is no `tests/`
directory, no `#[test]`, no `#[cfg(test)]`, no `g_test_add_func`). Parity is
0/0 and is met trivially. **The port therefore inherits no safety net** —
every check below was written for the port and pins nothing upstream
considered worth pinning.

## Extra

| File | Census rows | What it checks |
|---|---:|---|
| `test/catalogue_test.rb` | 17 | the PO parser and the os-release reader, no display needed |
| `test/cli_test.rb` | 6 | `--help`, an unknown option, argv forwarding to GApplication |
| `test/config_test.rb` | 28 | build-profile constants, the logger's level rules, the desktop/metainfo translation merge |
| `test/drive_tour.rb` | 47 | the full carousel walk: all 7 pages, all 4 `win.` actions, button fade/target state, the devel profile, the `Left`/`Right` key controller, the two window-close paths |
| `test/locale_test.rb` | 15 | the catalogue reaching the live widgets under `LANGUAGE=de` |
| `test/quit_test.rb` | 6 | `win.skip-tour` and `app.quit` each actually end the main loop, each in their own process |

(`test/gtk_driver.rb` is the harness `drive_tour.rb` and `locale_test.rb` run
through — correctly excluded by the census script's `*driver*` filter; it
contains no test cases of its own.)

The census rows above do not match a flat `grep -c 'check('` of the same
files (110 vs. 119) because `test-census.sh` also counts the `d.step`/`check`
calls the `GtkDriver` harness itself defines as assertion points plus the
block-form checks inside loops — read as leads, not exact per the skill's own
caution, and the authoritative number is the one the suite itself reports at
run time (below).

## The gate this round, reproduced

The task names a runtime gate of **43 checks, 0 failed**, which is exactly
`test/drive_tour.rb` alone, run this session:

```
nix develop --command xvfb-run -a ruby test/drive_tour.rb
...
43 of 43 checks passed
DRIVE OK
```

That number is real and reproducible, but it is **one file out of six**, and
the task is explicit that a narrow drive run is a gap in its own right. So
this session also ran the suite's actual target end to end, not just the one
file the gate quotes:

```
nix develop --command xvfb-run -a rake test
```

All six files in the `rake test` task list ran and every check in every one
of them passed — `catalogue_test.rb` ("all checks passed"), `config_test.rb`
("all checks passed"), `cli_test.rb` ("all checks passed"), `quit_test.rb`
("all checks passed"), `drive_tour.rb` ("43 of 43 checks passed, DRIVE OK"),
`locale_test.rb` ("11 of 11 checks passed, DRIVE OK"). Full output captured
in this session's transcript. This is a real, broad execution of the whole
declared test target, not a claim resting on the 43-check file alone — the
distinction the task asked this report to draw explicitly.

## Rules check

- Upstream has no tests to drop, merge, or lower — nothing in `## Extra`
  claims to be a ported upstream test.
- Every file in the `rake test` task's own list (`Rakefile`, `task :test`)
  was executed this session; none is declared and silently skipped.
- No check was found disabled, commented out, or pending in any test file
  (`grep -rn 'skip\|pending\|xit\|TODO' test/` returns nothing beyond the
  identifier matches already covered in `accountability-ensurance.md`).

## Verdict

Parity is 0/0, met trivially, with the "no inherited safety net" caveat
stated above rather than left implied. The port's own suite is real, covers
six separate files exercising every unit named in `component-parity.md`
(application, window, paginator, image page, i18n/catalogue, os-release,
config/profile, CLI argument handling, quit paths), and was executed in
full this session with every check green — not inferred from the narrower
43-check gate alone.
