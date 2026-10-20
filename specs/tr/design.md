# Design: tr

## Overview

`main()` passes `runtime.args()` to `cli.app.run`. `run` parses the options
and counts the operands (`cli.args`), handles `--help` and `--version`, then
builds a `Plan` from the two SETs (`commands.plan.make_plan`): parse, check,
and turn them into a delete set, a squeeze set and a translation table. Any
warnings are printed, then either the SET error (status 1) or the output of
`commands.tr.run_tr`, which reads standard input whole, decodes it and runs
each chunk through `filter_into`.

Characters are integers: Unicode code points, plus 256 "raw" codes above
U+10FFFF for bytes that are not well-formed UTF-8 (`commands.utf8`). The
SETs are kept as lists of elements and never expanded, because `[c*]` and
the complement of a SET can stand for more than a million characters.

## Modules

| Module | Contents |
|---|---|
| `source/main.loup` | entry point: `run(runtime.args())` |
| `source/appinfo.loup` | name, version, summary, exit statuses (GNU tr uses 1 for every error) |
| `source/cli/getopt.loup` | `OptSpec`, `OptHit`, `Scan`, `scan_options(argv, specs, in_order)`: a GNU `getopt_long` work-alike, with the `+` mode tr uses |
| `source/cli/args.loup` | `class Options`, `parse_args`: options, then GNU's operand-count rules and messages |
| `source/cli/quote.loup` | `quote` (gnulib's C-locale quoting), `printable`, `printable_char` (tr's own escaping of SET text) |
| `source/cli/usage.loup` | `usage()` help text, `version_line()` |
| `source/cli/app.loup` | `run()`: parse, help/version, plan, warnings, run, exit status |
| `source/commands/utf8.loup` | `RAW_BASE`, `decode_into`, `encode_into`, `codes_of`, `text_of` |
| `source/commands/escapes.loup` | `class Unquoted`, `unquote`: GNU's backslash escapes, with an escaped flag per character |
| `source/commands/sets.loup` | `enum Elem`, `class SetSpec` (elements and GNU's statistics), `parse_set`, `class SetCursor`, `spec_nth`, `homogeneous`, the character classes |
| `source/commands/charset.loup` | `class CharSet`: members as sorted ranges, complement, `contains`, `count_below`, `size` |
| `source/commands/plan.loup` | `class Plan`, `make_plan`: validation in GNU's order and the tables |
| `source/commands/tr.loup` | `filter_units`, `filter_into`, `tr_text`, `run_tr` |

### SETs

`unquote` decodes escapes and remembers which characters were escaped.
`parse_set` follows GNU's `build_spec_list`: at an unescaped `[` it tries
`[:name:]`, `[=c=]`, then `[c*n]`; otherwise an unescaped `-` between two
characters makes a range, and anything else is a single character. The
elements are `Single(c)`, `Span(first, last)`, `CharClass(n)`, `Equiv(c)`
and `Repeat(c, n)`, where `n` is 0 for `[c*]` until validation sizes it.

`SetSpec.compute_stats` is GNU's `get_spec_stats`: the length, whether
there are classes, restricted classes (other than lower/upper), equivalence
classes, and how many `[c*]` there are.

### Validation

`validate` in `plan.loup` runs GNU's checks in GNU's order, so that the
first problem reported is the same: SET1's length (the size of its
complement with `-c`), no `[c*]` in SET1, SET2's length with its `[c*]`
sized to fill up to SET1, at most one `[c*]`, then for translation: no
`[=c=]` or restricted class in SET2, the case-class alignment walk (GNU's
`validate_case_classes`, which also discounts each case pair to one
character), the extension of SET2 by its last character (an error if SET2
ends with a class), and the complemented-class rule.

### Tables

- Delete and squeeze sets are `CharSet`s: sorted, merged ranges and a
  256-entry table for the common codes, with a complement flag.
- Translation without `-c` walks SET1 and SET2 with two `SetCursor`s in
  step, as GNU's main loop does: each pair sets one entry (the last one
  wins), and a `[:lower:]`/`[:upper:]` pair maps the whole class and skips
  both elements. Codes below 256 go in a list, others in a `dict[int, int]`.
- With `-c`, the complement of SET1 is mapped in ascending order to SET2:
  the character `c` outside SET1 is the k-th member of the complement with
  `k = c - count_below(c)`, and maps to `spec_nth(SET2, k)` if SET2 is that
  long (it is unless `-t`). The 256 low codes are computed up front, the
  rest when they are met.

### The filter

`filter_into` takes each code: with `-d` it drops members of the delete
set, otherwise it translates when translating; then with `-s` it drops a
code equal to the last one written if it is in the squeeze set. The last
code written is passed from one chunk to the next.

`run_tr` reads standard input with `readBytes` (it cannot be read in
pieces), decodes 64 KiB at a time, filters, encodes and prints each chunk.
The three lists are reused between chunks (emptied with `pop`): the native
runtime does not free lists, and new ones per chunk cost 25 times the input
size in memory. Output that is well-formed UTF-8 is printed as a string;
output with raw bytes goes through C's `putchar` and `fflush`, the only way
to write such bytes from a native build.

## Error handling

- Usage errors (options, operand counts): `tr: MESSAGE`, the "Try" line,
  status 1.
- Invalid SETs and SETs that do not fit together: `tr: MESSAGE`, status 1,
  standard input not read. Warnings are printed first.
- Standard input that is a directory: checked before reading (the native
  runtime cannot catch read errors), `tr: read error: Is a directory`,
  status 1.

## Differences from GNU tr

- Characters are Unicode characters, not bytes: `tr 'éö' 'eo'` maps `é` to
  `e`, where GNU tr maps the bytes of the UTF-8 encodings one by one and
  mangles the text. ASCII input gives the same output as GNU.
- `\NNN` names the character U+0000 to U+00FF, not a byte: `\351` is `é`.
- Bytes that are not well-formed UTF-8 are passed through unchanged; they
  belong to no SET, only to complements.
- Classes hold ASCII characters only, as in GNU tr (its classes are byte
  classes).
- A repeat count must fit in a signed 64-bit integer (GNU: up to 2^64 - 2).
- Standard input is read whole; write errors on standard output are not
  reported.
- Messages use the C locale's quotes; non-ASCII characters in them are
  printed as they are.
- `--version` prints a single line; `--help` omits GNU's links.

## Testing

- Unit tests (`make test`, Stage0): one file per module, on the pure
  functions: option scanning and operand counts, quoting, UTF-8 decoding
  with raw bytes, escapes and warnings, SET parsing and errors, CharSet
  membership and counts, validation messages, and `tr_text` for every mode.
- End-to-end tests (`tests/e2e.sh`, the native binary): every option and
  construct, Unicode, raw bytes and NUL (expected files written with
  `printf`), squeezing and characters across the 64 KiB chunk boundary,
  every warning and error message with its status, help and version. The
  expected outputs were checked against GNU tr 9.5 (`LC_ALL=C`), which
  differs only on the cases listed above.
