# loup-cmd-tr

GNU `tr` recreated in [Loup](https://code-craft.ai/references/loup):
translate, delete or squeeze characters from standard input, with GNU's SET
language (`a-z`, `[:alpha:]`, `[=c=]`, `[c*n]`, escapes), its validation
rules and messages, working on Unicode characters rather than bytes.

Part of the **loup-cmd** series of example applications: classic Linux and
Windows commands, and projects for each Loup execution mode, each in its own
repository under [myronccai](https://github.com/myronccai?tab=repositories&q=loup-cmd).
This one is `host.dual` Loup built as a native binary.

## Requirements

- Loup 1.26.0 or later:

  ```sh
  curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.sh | sh
  ```

- `make`, and `clang` 17 or later for the native build.

## Usage

```sh
make build                                    # native binary: build/tr
make ci                                       # check, unit tests, build, end-to-end tests
echo hello | make run ARGS="a-z A-Z"          # run from source with loup run
```

```text
$ echo 'Hello, World' | build/tr a-z A-Z
HELLO, WORLD
$ echo 'Hello, World' | build/tr '[:lower:][:upper:]' '[:upper:][:lower:]'
hELLO, wORLD
$ echo 'one, two  three!' | build/tr -cs '[:alpha:]' '\n'
one
two
three
$ echo 'phone: +1 (555) 010-9999' | build/tr -cd '[:digit:]\n'
15550109999
$ echo 'too    many   spaces' | build/tr -s ' '
too many spaces
$ echo 'abcdef' | build/tr a-f '[x*2][y*]z'
xxyyyz
$ echo 'héllo wörld' | build/tr 'éö' 'eo'
hello world
$ echo 'abc' | build/tr 'a-c' 'αβγ'
αβγ
$ build/tr a-z '[:upper:]'; echo "exit $?"
tr: misaligned [:upper:] and/or [:lower:] construct
exit 1
$ build/tr a; echo "exit $?"
tr: missing operand after 'a'
Two strings must be given when translating.
Try 'tr --help' for more information.
exit 1
$ build/tr --version
tr (loup-cmd-tr) 0.1.0
```

`tr [OPTION]... SET1 [SET2]` reads standard input only. Options:

| Option | Meaning |
|---|---|
| `-c`, `-C`, `--complement` | use every character not in SET1, in ascending order |
| `-d`, `--delete` | delete the characters of SET1 instead of translating |
| `-s`, `--squeeze-repeats` | squeeze runs of a character of the last SET given into one, after translating or deleting |
| `-t`, `--truncate-set1` | cut SET1 to the length of SET2 instead of extending SET2 |
| `--help`, `--version` | print help or the version and exit |

What the operands mean:

| Command | Effect |
|---|---|
| `tr SET1 SET2` | translate each character of SET1 to the one at the same place in SET2 (SET2 is extended by repeating its last character) |
| `tr -d SET1` | delete SET1 |
| `tr -s SET1` | squeeze SET1 |
| `tr -s SET1 SET2` | translate, then squeeze SET2 |
| `tr -ds SET1 SET2` | delete SET1, then squeeze SET2 |

The SET language:

| Notation | Meaning |
|---|---|
| `\\ \a \b \f \n \r \t \v` | backslash and control characters; any other `\c` is `c` taken literally (`\-` is a plain dash) |
| `\NNN` | the character with octal value NNN (1 to 3 digits, up to `\377`) |
| `CHAR1-CHAR2` | the characters from CHAR1 to CHAR2 in ascending order |
| `[:alnum:]` `[:alpha:]` `[:blank:]` `[:cntrl:]` `[:digit:]` `[:graph:]` `[:lower:]` `[:print:]` `[:punct:]` `[:space:]` `[:upper:]` `[:xdigit:]` | character classes (ASCII); `[:lower:]` facing `[:upper:]` converts case |
| `[=C=]` | the character C |
| `[C*N]` | N copies of C (N octal if it starts with 0) |
| `[C*]` | in SET2, copies of C up to the length of SET1 |

Options must come before the SETs: the first operand ends the options, so
`tr l -d` translates `l` to `-`. Short options may be combined (`-cs`) and
long ones shortened (`--comp`).

Exit status: `0` on success; `1` on a usage error, an invalid SET, or a
read error, as in GNU tr.

## Differences from the original

- **Characters, not bytes.** Input is decoded as UTF-8 and every Unicode
  character counts as one character, in the input and in the SETs, so
  `tr 'éö' 'eo'` turns `héllo wörld` into `hello world`. GNU tr 9.5 works on
  bytes: it pairs the bytes of the UTF-8 encodings and prints
  `hoollo woorld`. Ranges of non-ASCII characters (`α-ω`) work. ASCII input
  gives exactly GNU's output.
- `\NNN` is the character with that code point (U+0000 to U+00FF), not a
  byte: `tr a '\351'` writes `é`, and `tr -d '\200-\377'` deletes the
  characters U+0080 to U+00FF rather than every byte of a multibyte
  character (keep ASCII only with `tr -cd '\000-\177'`, which works the
  same in both).
- Bytes that are not well-formed UTF-8 are passed through unchanged. They
  belong to no SET, only to complements: `tr -c 'a-z' '?'` replaces each of
  them with `?`, as GNU does.
- The classes hold ASCII characters only, as in GNU tr, whose classes are
  byte classes; `[:upper:]` does not include `À`.
- A repeat count in `[c*n]` must fit in a signed 64-bit integer (GNU
  allows up to 2^64 - 2).
- Standard input is read whole before any output (Loup 1.26.0 has no
  streaming reader), so `tr` cannot work on an endless stream.
- Write errors on standard output (a full disk, `> /dev/full`) are not
  reported; GNU prints `tr: write error: ...` and exits with 1.
- Messages use the C locale's quotes (`'x'`, not `‘x’`); non-ASCII
  characters in them are printed as they are rather than as octal escapes.
- `--version` prints a single line; `--help` omits GNU's links to its
  online documentation and adds a note on characters.

## Layout

```text
source/main.loup              # entry point
source/appinfo.loup           # name, version, exit statuses
source/cli/getopt.loup        # GNU getopt_long work-alike, with getopt's "+" mode
source/cli/args.loup          # tr's options and operand-count rules
source/cli/quote.loup         # GNU-style quoting and escaping in messages
source/cli/usage.loup         # --help and --version text
source/cli/app.loup           # run(): parse, plan, warnings, exit status
source/commands/utf8.loup     # UTF-8 decoding and encoding; raw bytes
source/commands/escapes.loup  # backslash escapes in SETs
source/commands/sets.loup     # SET parsing into elements; cursor; classes
source/commands/charset.loup  # sets of characters as sorted ranges
source/commands/plan.loup     # validation and the delete, squeeze and translation tables
source/commands/tr.loup       # the filter; reading and writing
tests/*_test.loup             # unit tests (make test)
tests/e2e.sh                  # end-to-end tests of build/tr (make e2e)
specs/tr/                     # requirements, design, tasks
```

[AGENTS.md](AGENTS.md) has every build and test command and the conventions
for changing the code.
