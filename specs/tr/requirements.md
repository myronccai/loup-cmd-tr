# Requirements: tr

## Introduction

`tr` copies standard input to standard output, translating, deleting or
squeezing characters on the way. Two operands, SET1 and SET2, name the
characters with a small language: backslash escapes, ranges such as `a-z`,
classes such as `[:alpha:]`, equivalence classes `[=c=]` and repeats
`[c*n]`. This repository recreates GNU coreutils `tr` in Loup, with its
option grammar, SET language, validation rules, messages and exit statuses.
Shell users and scripts use it to change case, strip or squeeze characters,
and split text into words.

## Requirements

### Requirement 1: Translation

**User Story:** As a shell user, I want to replace each character of SET1
with the character at the same position in SET2 so that I can change case
or map characters.

#### Acceptance Criteria

1. WHEN SET1 and SET2 are given without `-d`, THE program SHALL replace
   every character of SET1 in the input with the character at the same
   position in SET2.
2. WHEN SET2 is shorter than SET1, THE program SHALL extend it by repeating
   its last character, unless `-t` is given, in which case SET1 SHALL be
   truncated to the length of SET2.
3. WHEN a character appears more than once in SET1, THE program SHALL use
   the last pairing.
4. WHEN `[:lower:]` and `[:upper:]` (in either order) face each other in
   SET1 and SET2, THE program SHALL convert case.

### Requirement 2: The SET language

**User Story:** As a shell user, I want GNU tr's notation for SETs so that
existing commands and scripts work.

#### Acceptance Criteria

1. THE program SHALL decode `\\`, `\a`, `\b`, `\f`, `\n`, `\r`, `\t`, `\v`
   and `\NNN` (one to three octal digits, at most `\377`); any other
   escaped character SHALL stand for itself and never start or end a
   construct.
2. THE program SHALL expand `CHAR1-CHAR2` to the characters from CHAR1 to
   CHAR2 in ascending order.
3. THE program SHALL accept the classes `[:alnum:]`, `[:alpha:]`,
   `[:blank:]`, `[:cntrl:]`, `[:digit:]`, `[:graph:]`, `[:lower:]`,
   `[:print:]`, `[:punct:]`, `[:space:]`, `[:upper:]` and `[:xdigit:]`,
   each holding the ASCII characters of the C locale's class.
4. THE program SHALL accept `[=c=]` as the character c.
5. THE program SHALL accept `[c*n]` as n copies of c (n octal when it
   starts with 0) and, in SET2, `[c*]` as copies of c up to the length of
   SET1.
6. WHEN a backslash ends a SET, or an octal escape exceeds `\377`, THE
   program SHALL print GNU tr's warning and go on.

### Requirement 3: Deleting and squeezing

**User Story:** As a shell user, I want to delete characters and squeeze
runs of them so that I can clean up text.

#### Acceptance Criteria

1. WHEN `-d` is given, THE program SHALL delete the characters of SET1.
2. WHEN `-s` is given, THE program SHALL replace each run of a repeated
   character that is in the last SET given (SET1 with one SET, SET2 with
   two) by one occurrence, after translating or deleting.
3. WHEN squeezing, THE program SHALL compare each character with the last
   one written, so that runs spanning any input boundary are squeezed.

### Requirement 4: Complement

**User Story:** As a shell user, I want to work on every character not in
SET1 so that I can keep only some characters or split text into words.

#### Acceptance Criteria

1. WHEN `-c` or `-C` is given, THE program SHALL use the complement of
   SET1: every character not in it, in ascending order.
2. WHEN translating with `-c`, THE program SHALL map the complement, in
   order, to SET2 as extended by requirement 1.2.

### Requirement 5: Characters and bytes

**User Story:** As a user of UTF-8 text, I want tr to work on characters so
that accented letters and other scripts are not split into bytes.

#### Acceptance Criteria

1. THE program SHALL read standard input as UTF-8 and treat each Unicode
   character as one character, in the input and in the SETs.
2. WHEN the input contains bytes that are not well-formed UTF-8, THE
   program SHALL pass them through unchanged, except that they SHALL belong
   to the complement of any SET1.
3. THE program SHALL handle NUL characters in the input and in the SETs.

### Requirement 6: Command line

**User Story:** As a script author, I want tr's options, operand rules and
messages to match GNU tr so that it can replace it.

#### Acceptance Criteria

1. THE program SHALL accept `-c`, `-C`, `--complement`, `-d`, `--delete`,
   `-s`, `--squeeze-repeats`, `-t`, `--truncate-set1`, `--help` and
   `--version`, with clustering and unambiguous long-option prefixes; the
   first operand SHALL end the options.
2. THE program SHALL require two SETs when translating or with both `-d`
   and `-s`, exactly one with `-d` alone, and one or two with `-s` alone,
   and report a wrong count with GNU tr's message, the "Try" line and
   status 1.
3. WHEN a SET is invalid or the SETs do not fit together, THE program SHALL
   print GNU tr's message for it and exit with status 1 without reading
   input.
4. WHEN standard input is a directory, THE program SHALL print
   `tr: read error: Is a directory` and exit with status 1.
5. THE program SHALL exit with status 0 after copying its input.
