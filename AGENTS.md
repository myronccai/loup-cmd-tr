# AGENTS.md

This repository recreates GNU `tr` in the Loup programming language, as part
of the loup-cmd series of example applications. The program is `host.dual`
Loup built as a native executable. It works on Unicode characters, not bytes.

## Skills

| Skill | Location | Use it when |
|-------|----------|-------------|
| `loup-programmer` | [skills/loup-programmer/SKILL.md](skills/loup-programmer/SKILL.md) | Writing, reviewing, debugging or explaining Loup code: `.lpscr`, `.loup`, `.lphc`, `.lpweb` or `.lpfree` source files, `.lppkg` manifests, `@mode(...)` directives, or the `loup` / `loup-bootstrap` commands. |

Read `skills/loup-programmer/SKILL.md` before writing or changing any Loup code
in this repository. It links to detailed references under
`skills/loup-programmer/references/` for syntax, types and ownership, execution
modes and projects, errors and diagnostics, the standard library, and common
mistakes. Load those only as needed.

## Code layout

```text
.
├── package.lppkg                # Loup manifest: name, version, toolchain, [build] entry, [test] pattern
├── Makefile                     # run, check, test, build, e2e, ci, clean
├── source/                      # all Loup code; modules import each other by path from here
│   ├── main.loup                # entry point: func main() calls run(runtime.args())
│   ├── appinfo.loup             # APP_NAME, APP_VERSION, APP_SUMMARY, exit statuses
│   ├── cli/
│   │   ├── getopt.loup          # scan_options(): GNU getopt_long rules and messages, "+" mode
│   │   ├── args.loup            # class Options, parse_args(): tr's options and operand counts
│   │   ├── quote.loup           # quote(), printable(): GNU-style text in messages
│   │   ├── usage.loup           # usage(), version_line()
│   │   └── app.loup             # run(): parse, --help/--version, make_plan, run_tr, exit status
│   └── commands/
│       ├── utf8.loup            # decode_into(), encode_into(): code points and raw bytes
│       ├── escapes.loup         # class Unquoted, unquote(): backslash escapes with escaped flags
│       ├── sets.loup            # enum Elem, class SetSpec, parse_set(), class SetCursor, classes
│       ├── charset.loup         # class CharSet: sorted ranges, contains(), count_below()
│       ├── plan.loup            # class Plan, make_plan(): GNU's validation, tables
│       └── tr.loup              # filter_units(), tr_text(), run_tr()
├── tests/
│   ├── *_test.loup              # unit tests: func test_*(): void
│   └── e2e.sh                   # end-to-end tests of the native binary
├── specs/tr/                    # requirements.md, design.md, tasks.md
├── skills/loup-programmer/      # the Loup skill and its references
├── .github/workflows/ci.yml     # installs Loup and runs `make ci`
└── build/                       # build output (git-ignored)
```

## Build, run and test

Prerequisites: Loup 1.26.0 (`loup` and `loup-bootstrap` on `PATH`), `make`,
and `clang` 17 or later for native builds.

| Task | Command | Notes |
|------|---------|-------|
| Run from source | `echo hello \| make run ARGS="a-z A-Z"` | `loup run source/main.loup -- ARGS`; output with bytes that are not UTF-8 needs the native build |
| Type-check | `make check` | checks `source/main.loup` and every module it imports; tests are not checked |
| Run all tests | `make test` | every `tests/*_test.loup`, one at a time |
| Run matching tests | `make test TEST_ARGS="--filter case"` | tests whose name contains `case` |
| Run one test file | `make test TEST_ARGS="--file tests/sets_test.loup"` | |
| Build | `make build` | native binary at `build/tr` |
| Run the binary | `build/tr --help` | |
| End-to-end tests | `make e2e` | runs `tests/e2e.sh build/tr`: output compared byte for byte |
| Everything CI runs | `make ci` | check, test, build, e2e, then `build/tr --version` |
| Clean | `make clean` | removes `build/` and `.temp/` |

Run `make ci` before reporting a change as done. `loup run` and the native
build do not support the same things, so a change can pass `make test` and
still fail `make build`.

Do not call `loup test` or `loup check` directly on Linux x86-64. There `loup`
is the self-hosted driver: it refuses `check`, and its test runner cannot
resolve this project's imports. The Makefile uses `loup-bootstrap` (Stage0) for
both, and sets `LOUPPATH=source` for tests.

## Making a change

1. Update the spec in `specs/tr/` (see [specs/README.md](specs/README.md)).
2. Change the code under `source/`.
3. Add or update unit tests in `tests/` and cases in `tests/e2e.sh`.
4. Run `make ci`.
5. Tick the finished tasks in `specs/tr/tasks.md`.

Keep behaviour in pure functions that return values (`tr_text` and
`filter_units` return the output, `make_plan` returns the plan or the
message) so unit tests can check it; only `run_tr` reads and prints.

## Conventions

- Every source file is `@mode(host.dual)` with the `.loup` extension. Only
  `source/main.loup` has a `main()`.
- Modules import each other by path from `source/`:
  `from cli.args import (Options);`. Tests import them the same way. Do not
  use relative imports (`from .args import ...`): the self-hosted `loup run`
  on Linux x86-64 fails on them.
- Records shared between modules are classes (`Options`, `SetSpec`, `Plan`),
  and the few structs (in `getopt.loup`) have field names used nowhere else:
  the native build lays out struct fields by name across the whole program.
- Write `match` on enums with payloads in statement form, with a `return`
  or an assignment in each arm.
- The native build supports less than `loup run` does. For example,
  `list.is_empty()`, `list.map()` and `list.clear()` fail native codegen
  (`E-CODEGEN-UNHANDLED-METHOD`); use `len() == 0`, a loop, and `pop()`.
- The native runtime never frees lists or strings it allocates in a loop:
  `run_tr` reuses its chunk buffers instead of making new ones.
- Characters are `int` code points; bytes that are not UTF-8 are the codes
  `RAW_BASE + byte`. Classes are ASCII only.
- GNU tr is installed here as `gnutr` (plain `tr` may be uutils); compare
  behaviour with it (`LC_ALL=C gnutr ...`), but write expected output into
  `tests/e2e.sh`.
- Keep `APP_VERSION` in `source/appinfo.loup` equal to `version` in
  `package.lppkg`.
- The skill's examples use the `loup init` layout (`src/`, `tests/`, and
  `from ..src.x import` in tests). This project uses `source/` and
  `tests/` with plain imports; follow this file.
- The skill documents toolchain 1.25.1; this template targets 1.26.0. When
  they disagree, trust the toolchain's behaviour.
