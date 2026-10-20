#!/usr/bin/env bash
# End-to-end tests: run the built binary and compare its standard output
# (byte for byte) and exit status with the expected ones, and for errors
# its standard error.
#
# usage: tests/e2e.sh BINARY

set -u
BIN=$1
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0
fail=0

# check_file NAME STATUS EXPECTED_FILE [ARGS...]
# Runs BINARY ARGS... with standard input from the file named by $IN
# (default: /dev/null) and compares standard output with EXPECTED_FILE.
check_file() {
    local name=$1 want_status=$2 want_file=$3
    shift 3
    "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    local status=$?
    if [ "$status" -eq "$want_status" ] && cmp -s "$want_file" "$TMP/out"; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff <(od -c "$want_file") <(od -c "$TMP/out") | sed 's/^/    /' | head -20
        sed 's/^/    stderr: /' "$TMP/err" | head -5
    fi
}

# check NAME STATUS EXPECTED_STDOUT [ARGS...]
# As check_file, with the expected output given as a string. Bash strings
# cannot hold NUL bytes; use check_file for output that contains them.
check() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want"
    shift 3
    check_file "$name" "$want_status" "$TMP/want" "$@"
}

# check_err NAME STATUS EXPECTED_STDERR [ARGS...]
# Runs BINARY ARGS... as check_file does and compares standard error.
check_err() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want_err"
    shift 3
    "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    local status=$?
    if [ "$status" -eq "$want_status" ] && cmp -s "$TMP/want_err" "$TMP/err"; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff "$TMP/want_err" "$TMP/err" | sed 's/^/    /' | head -10
    fi
}

TRY=$'\nTry \'tr --help\' for more information.\n'

# Translation.
IN=<(printf 'hello, world\n') check "ranges"            0 $'HELLO, WORLD\n'    a-z A-Z
IN=<(printf 'aabbcc!\n') check "SET2 extended"          0 $'xxxxxx!\n'         abc x
IN=<(printf 'abcdef\n') check "-t truncates SET1"       0 $'xycdef\n'          -t a-f xy
IN=<(printf 'a\n') check "last pairing wins"            0 $'y\n'               aa xy
IN=<(printf 'abcdef\n') check "[c*] fills SET2"         0 $'xxyyyz\n'          a-f '[x*2][y*]z'
IN=<(printf 'abcdefghij\n') check "[c*n] octal"         0 $'xxxxxxxxij\n'      -t a-j '[x*010]'
IN=<(printf 'a b\tc\n') check "escapes"                 0 $'a_b_c_'            ' \t\n' '_'
IN=<(printf 'aAb\n') check "octal escapes"              0 $'bBb\n'             '\141\101' '\142\102'
IN=<(printf 'a\\b\n') check "escaped backslash"         0 $'a/b\n'             '\\' /
IN=<(printf 'a-c\n') check "escaped dash"               0 $'XYZ\n'             'a\-c' XYZ
IN=<(printf 'a-b\n') check "trailing dash"              0 $'xyb\n'             a- xy
IN=<(printf 'a]b[c\n') check "brackets"                 0 $'ayBxc\n'           '[]b' xyB
IN=<(printf 'a.b.c\n') check "equivalence class"       0 $'a!b!c\n'           '[=.=]' '!'

# Classes and case conversion.
IN=<(printf 'Hello World\n') check "lower to upper"     0 $'HELLO WORLD\n'     '[:lower:]' '[:upper:]'
IN=<(printf 'Hello World\n') check "upper to lower"     0 $'hello world\n'     '[:upper:]' '[:lower:]'
IN=<(printf 'Hello World\n') check "swap case"          0 $'hELLO wORLD\n'     '[:lower:][:upper:]' '[:upper:][:lower:]'
IN=<(printf 'ab\n') check "case pair overrides"         0 $'AB\n'              'a[:lower:]' 'X[:upper:]'
IN=<(printf 'R2-D2 & C-3PO\n') check "[:alnum:] to [n*]" 0 $'nn-nn & n-nnn\n'  '[:alnum:]' '[n*]'
IN=<(printf 'a1b2 c3\n') check "-d space"               0 $'a1b2c3\n'          -d ' '
IN=<(printf 'Hello World 123\t!\n') check "-d space and punct" 0 'HelloWorld123' -d '[:space:][:punct:]'
IN=<(printf 'f00d BEEF xyz\n') check "-d xdigit"        0 $'  xyz\n'          -d '[:xdigit:][:upper:]'

# Characters, not bytes.
IN=<(printf 'héllo wörld\n') check "Unicode SETs"       0 $'hello world\n'     'éö' eo
IN=<(printf 'abc\n') check "Unicode SET2"               0 $'αβγ\n'             a-c 'α-γ'
IN=<(printf 'αβγ\n') check "Unicode range"              0 $'abc\n'             'α-γ' a-c
IN=<(printf 'naïve café\n') check "-d one character"    0 $'naïve caf\n'       -d é
IN=<(printf 'ÀB\n') check "classes are ASCII"           0 $'Àb\n'              '[:upper:]' '[:lower:]'
IN=<(printf 'ab\n') check "\\377 is U+00FF"             0 $'ÿb\n'              a '\377'

# Complement.
IN=<(printf 'hi, you!\n') check "-c"                    0 'hiXXyouXX'          -c a-z X
IN=<(printf 'ab1\n') check "-c ascending order"         0 'a999'               -c a 0-9
IN=<(printf '\001\002\003a') check "-ct"                0 $'y\002\003a'        -ct a xy
IN=<(printf 'one, two  three!\n') check "-cs words"     0 $'one\ntwo\nthree\n' -cs '[:alpha:]' '\n'
IN=<(printf 'Hello, World!\n') check "-c class [c*]"    0 'Hello__World__'     -c '[:alpha:]' '[_*]'
IN=<(printf 'a1b22c333\n') check "-cd"                  0 '122333'             -cd '[:digit:]'
IN=<(printf 'a1b2\n') check "-C"                        0 $'a?b?\n'            -C '[:alpha:]\n' '?'
IN=<(printf 'a1b2\n') check "--complement"              0 $'a?b?\n'            --complement '[:alpha:]\n' '?'

# Deleting and squeezing.
IN=<(printf 'a1b22c333\n') check "-d"                   0 $'abc\n'             -d '[:digit:]'
IN=<(printf 'a  b   c\n') check "-s"                    0 $'a b c\n'           -s ' '
IN=<(printf 'aabbcc  dd\n') check "-s SET1 only"        0 $'abc  d\n'          -s a-z
IN=<(printf 'aabbccdd\n') check "-s squeezes SET2"      0 $'xy\n'              -s a-d xxyy
IN=<(printf 'abba\n') check "-ds"                       0 $'a\n'               -ds b a
IN=<(printf 'a\n\n\nb\n\n') check "squeeze blank lines" 0 $'a\nb\n'            -s '\n'
IN=<(printf '%300000s' '') check "squeeze across chunks" 0 ' '                 -s ' '
IN=<(printf '%65535s' ''; printf 'é\n') check "character across chunks" 0 $'é\n' -d ' '
IN=<(printf '') check "empty input"                     0 ''                   a b

# Bytes that are not UTF-8, and NUL.
printf 'a\377b\342\202\n' > "$TMP/raw_in"
printf 'A\377B\342\202\n' > "$TMP/raw_want"
IN="$TMP/raw_in" check_file "raw bytes pass through" 0 "$TMP/raw_want"        ab AB
IN="$TMP/raw_in" check "raw bytes are in the complement" 0 $'a?b??\n'          -c 'ab\n' '?'
printf 'a\0b\0\n' > "$TMP/nul_in"
IN="$TMP/nul_in" check "NUL to x"                       0 $'axbx\n'            '\000' x
printf '\0b\n' > "$TMP/nul_want"
IN=<(printf 'ab\n') check_file "x to NUL"               0 "$TMP/nul_want"      a '\0'
IN="$TMP/nul_in" check "-d NUL"                         0 $'ab\n'              -d '\0'

# Option parsing.
IN=<(printf 'hello\n') check "first operand ends options" 0 $'he--o\n'         l -d
IN=<(printf 'hello\n') check "-- ends options"          0 $'heLLo\n'           -- -l L
IN=<(printf 'a-b\n') check "--delete abbreviated"       0 $'-b\n'              --del a
IN=<(printf 'aab\n') check "--squeeze-repeats"          0 $'ab\n'              --squeeze-repeats a
IN=<(printf 'abc\n') check "--truncate-set1"            0 $'xyc\n'             --truncate-set1 abc xy
IN=<(printf 'ab\n') check "-A is accepted"              0 $'bb\n'              -A a b

# Warnings: printed, and tr goes on.
IN=<(printf 'a b\n') check "ambiguous octal output"     0 $'a_b\n'             '\400' _
check_err "ambiguous octal"                             0 $'tr: warning: the ambiguous octal escape \\400 is being\n\tinterpreted as the 2-byte sequence \\040, 0\n' '\400' x
check_err "backslash at the end"                        0 $'tr: warning: an unescaped backslash at end of string is not portable\n' 'a\' x

# Usage errors.
check_err "no operands"         1 "tr: missing operand$TRY"
check_err "one string"          1 "tr: missing operand after 'a'"$'\nTwo strings must be given when translating.'"$TRY" a
check_err "-ds one string"      1 "tr: missing operand after 'a'"$'\nTwo strings must be given when both deleting and squeezing repeats.'"$TRY" -ds a
check_err "-d two strings"      1 "tr: extra operand 'b'"$'\nOnly one string may be given when deleting without squeezing repeats.'"$TRY" -d a b
check_err "three strings"       1 "tr: extra operand 'c'$TRY"                  a b c
check_err "quoted operand"      1 "tr: missing operand after 'it\\'s'"$'\nTwo strings must be given when translating.'"$TRY" "it's"
check_err "invalid option"      1 "tr: invalid option -- 'x'$TRY"              -x
check_err "unknown long"        1 "tr: unrecognized option '--nope'$TRY"       --nope
check_err "no argument allowed" 1 "tr: option '--complement' doesn't allow an argument$TRY" --complement=1 a

# Bad SETs: a message, no "Try" line.
check_err "invalid class"       1 $'tr: invalid character class \'foo\'\n'     '[:foo:]' x
check_err "empty class"         1 $'tr: missing character class name \'[::]\'\n' '[::]' x
check_err "empty equivalence"   1 $'tr: missing equivalence class character \'[==]\'\n' '[==]' x
check_err "long equivalence"    1 $'tr: ab: equivalence class operand must be a single character\n' '[=ab=]' x
check_err "reversed range"      1 $'tr: range-endpoints of \'z-a\' are in reverse collating sequence order\n' z-a x
check_err "bad repeat count"    1 $'tr: invalid repeat count \'09\' in [c*n] construct\n' '[a*09]' x
check_err "escaped class name"  1 $'tr: invalid character class \'\\\\t\'\n'  '[:\t:]' x
check_err "[c*] in SET1"        1 $'tr: the [c*] repeat construct may not appear in string1\n' '[a*]' x
check_err "two [c*]"            1 $'tr: only one [c*] repeat construct may appear in string2\n' a '[a*][b*]'
check_err "[c*] with -ds"       1 $'tr: the [c*] construct may appear in string2 only when translating\n' -ds a '[b*]'
check_err "equivalence in SET2" 1 $'tr: [=c=] expressions may not appear in string2 when translating\n' a '[=a=]'
check_err "class in SET2"       1 $'tr: when translating, the only character classes that may appear in\nstring2 are \'upper\' and \'lower\'\n' a '[:alpha:]'
check_err "misaligned"          1 $'tr: misaligned [:upper:] and/or [:lower:] construct\n' a-z '[:upper:]'
check_err "empty SET2"          1 $'tr: when not truncating set1, string2 must be non-empty\n' a ''
check_err "SET2 ends in a class" 1 $'tr: when translating with string1 longer than string2,\nthe latter string must not end with a character class\n' '[:upper:]a' '[:lower:]'
check_err "complemented class"  1 $'tr: when translating with complemented character classes,\nstring2 must map all characters in the domain to one\n' -c '[:alpha:]' xy
IN=/ check_err "directory on stdin" 1 $'tr: read error: Is a directory\n'           a b

# Help and version.
check "version"                 0 $'tr (loup-cmd-tr) 0.1.0\n'                  --version
check "help wins"               0 "$("$BIN" --help)"$'\n'                       --help -x
"$BIN" --help | head -1 | grep -q '^Usage: tr \[OPTION\]... STRING1 \[STRING2\]' && pass=$((pass + 1)) || { fail=$((fail + 1)); echo "FAIL: help text"; }

echo "e2e: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
