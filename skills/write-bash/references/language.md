# Bash 5.3+ Language Reference

Focused on programming features. For style rules see SKILL.md. For patterns see
patterns.md.

## Contents

- [Typed declarations](#typed-declarations)
- [Parameter expansion](#parameter-expansion)
- [Indexed arrays](#indexed-arrays)
- [Associative arrays](#associative-arrays)
- [Namerefs](#namerefs)
- [Conditionals](#conditionals)
- [Arithmetic](#arithmetic)
- [Case statements](#case-statements)
- [Loops](#loops)
- [Process substitution and here-strings](#process-substitution-and-here-strings)
- [File descriptors](#file-descriptors)
- [Concurrency](#concurrency)
- [Coprocesses](#coprocesses)
- [Builtins quick reference](#builtins-quick-reference)
- [Special parameters](#special-parameters)
- [Quoting rules](#quoting-rules)
- [Expansion order](#expansion-order)
- [Shopt reference](#shopt-reference)

## Typed declarations

``` bash
declare -A config=()           # associative array
declare -n ref=$1              # nameref (alias to another variable)
declare -i count=0             # integer (arithmetic on assignment)
declare -ri MAX_RETRIES=3      # readonly integer constant
declare -a files=()            # indexed array
declare -x PATH                # export to environment
declare -g var=value           # force global from inside function
local var=value                # local to current function scope

# simple assignment for basic strings

name='john'
output_file='/tmp/result.txt'
```

## Parameter expansion

``` bash
${var:-default}                # default if unset or null
${var:=default}                # assign default if unset or null
${var:?error message}          # abort with message if unset or null
${var:+alternate}              # alternate value if set and non-null

${var#pattern}                 # remove shortest prefix match (glob)
${var##pattern}                # remove longest prefix match
${var%pattern}                 # remove shortest suffix match
${var%%pattern}                # remove longest suffix match

${var/old/new}                 # replace first match
${var//old/new}                # replace all matches
${var/#pattern/repl}           # replace if matches start
${var/%pattern/repl}           # replace if matches end

${#var}                        # string length
${var:offset:length}           # substring
${#arr[@]}                     # array length

${var^^}                       # uppercase all
${var,,}                       # lowercase all
${var^}                        # capitalize first

${var@Q}                       # shell-quoted form
${var@P}                       # prompt-string expansion
${var@E}                       # escape sequences expanded
${var@a}                       # attribute flags of variable

${!prefix*}                    # names of vars starting with prefix
${!arr[@]}                     # all indices/keys of array
${!name}                       # indirect expansion: value of $name-as-name
```

## Indexed arrays

``` bash
arr=(alpha beta gamma)
printf '%s\n' "${arr[@]}"      # iterate (each element as own word)
printf '%s\n' "${!arr[@]}"     # indices
arr+=("delta")                 # append
unset 'arr[1]'                 # delete element
echo "${#arr[@]}"              # length
echo "${arr[@]:1:2}"           # slice (offset:length)

# read file into array

mapfile -t lines < file.txt

# read with custom delimiter

readarray -d ':' -t segments < <(printf '%s' "$PATH")

# mapfile with callback

mapfile -c1 -C 'process_line' -t lines < input.txt
```

## Associative arrays

``` bash
declare -A phone=(
  [alice]="+49-123"
  [bob]="+1-456"
)

phone["charlie"]="+44-789"

for k in "${!phone[@]}"; do
  printf '%s => %s\n' "$k" "${phone[$k]}"
done

# test key existence (correct way, Bash 4.3+)

[[ -v phone[alice] ]] && printf 'found\n'

# do NOT use: [[ -n ${phone[$k]+x} ]]   (less readable)
# do NOT use: [[ ${phone[$k]:-} ]]       (fails on empty values)

```

## Namerefs

``` bash

# pass array by reference
# arr_ref - nameref to array

process_array() {
  local -n arr_ref=$1
  local item
  for item in "${arr_ref[@]}"; do
    printf 'processing: %s\n' "$item"
  done
}

declare -a my_files=(a.txt b.txt)
process_array my_files

# return value by reference

make_result() {
  local -n out=$1
  out="computed value"
}
make_result my_var
```

## Conditionals

`[[ ]]` for all tests. Never `[ ]` or `test`.

``` bash

# string tests

[[ -z $s ]]                    # empty
[[ -n $s ]]                    # non-empty
[[ $a == "$b" ]]               # equal (glob on RHS unless quoted)
[[ $a != "$b" ]]               # not equal
[[ $a < $b ]]                  # lexicographic less-than

# pattern matching (glob)

[[ $s == *.txt ]]
[[ $s == foo?(bar) ]]          # extglob: optional "bar"

# regex matching (ERE)

if [[ $s =~ ^([0-9]+):([A-Za-z_]+)$ ]]; then
  id=${BASH_REMATCH[1]}
  name=${BASH_REMATCH[2]}
fi

# file tests

[[ -f path ]]                  # regular file
[[ -d dir ]]                   # directory
[[ -L path ]]                  # symlink
[[ -e path ]]                  # exists
[[ -r file ]]                  # readable (-w writable, -x executable)
[[ -s file ]]                  # size > 0
[[ -p path ]]                  # named pipe
[[ -S path ]]                  # socket
[[ -N file ]]                  # modified since last read

# logical

[[ expr1 && expr2 ]]
[[ expr1 || expr2 ]]
[[ ! expr ]]
```

## Arithmetic

``` bash
(( i = 0 ))
(( i++ ))
(( result = a + b * 10 ))
(( a > b )) && printf 'a wins\n'

for (( i=0; i<n; i++ )); do
  (( i % 2 )) || printf '%d even\n' "$i"
done

# assignment via expansion

result=$(( a + b ))

# printf -v for formatted assignment

printf -v formatted_date '%(%Y-%m-%d)T' -1
```

## Case statements

``` bash
case $token in
  +([0-9]))       kind=num ;;
  @(yes|y|true))  kind=true ;;
  *.txt)          kind=text ;;
  *)              kind=other ;;
esac
```

## Loops

``` bash

# word iteration

for item in "${array[@]}"; do
  printf '%s\n' "$item"
done

# arithmetic

for (( i=0; i<n; i++ )); do
  :
done

# while with read (streaming, preferred for large input)

while IFS= read -r line || [[ -n $line ]]; do
  printf 'line: %s\n' "$line"
done < input.txt

# until (inverse of while)

until some_condition; do
  :
done

# break/continue with nesting depth

for ...; do
  for ...; do
    break 2    # break both loops
  done
done
```

Prefer streaming `while IFS= read -r` for large/unbounded input.
Use `mapfile` for small bounded data that fits comfortably in memory.

## Process substitution and here-strings

``` bash

# process substitution: command output as file path

diff <(sort file1) <(sort file2)
tee >(logger -t myapp) >(cat > copy.txt)

# here-string: string as stdin

grep -c 'pattern' <<< "$content"

# here-doc (single-quoted delimiter disables expansion)

cat <<'EOF'
$this and $(that) will NOT expand
EOF

# here-doc with <<- strips leading tabs (not spaces)

if true; then
	cat <<-EOF
	indented content (tabs stripped on output)
	EOF
fi
```

## File descriptors

``` bash

# open for reading

exec {fd}< input.txt
while read -ru "$fd" line; do
  printf 'line: %s\n' "$line"
done
exec {fd}<&-                   # close

# open for writing

exec {fd}>output.txt
printf 'data\n' >&"$fd"
exec {fd}>&-                   # close

# redirect trace to file

exec {TRACE_FD}>trace.log
BASH_XTRACEFD=$TRACE_FD
set -x

# redirect shortcuts

cmd >out 2>&1                  # stdout + stderr to file (order matters)
cmd &>out                      # bash shortcut: both to file
cmd 2>err.log                  # stderr only
cmd >>append.log               # append (set -C / noclobber blocks >)
```

## Concurrency

``` bash
task_a & pid_a=$!
task_b & pid_b=$!
wait "$pid_a"                  # wait specific
wait -n                        # wait any child (Bash 4.3+)

# pipeline statuses

cmd1 | cmd2 | cmd3
printf '%s\n' "${PIPESTATUS[@]}"
```

## Coprocesses

``` bash
coproc AWK { awk '{print toupper($0)}'; }
printf 'hello\n' >&"${AWK[1]}"
read -r result <&"${AWK[0]}"
kill "$COPROC_PID" 2>/dev/null || true
```

`coproc NAME { ...; }` creates array: `[0]` = read FD, `[1]` = write FD.

## Builtins quick reference

``` text
declare/typeset/local   variables, arrays, attributes (-a -A -i -n -r -x -g)
printf -v var fmt args  assign formatted string to variable
read -r [-d delim]      raw read; -a array; -N/-n N; -u FD; -t sec
mapfile -t arr          read lines into array (alias: readarray)
getopts                 portable option parsing (OPTIND, OPTARG)
set                     options: -e -E -u -o pipefail -x -T (functrace)
shopt                   language toggles (see shopt reference below)
trap 'handler' SIGNALS  ERR EXIT INT TERM DEBUG RETURN
wait [-n] [pid...]      synchronize
command/builtin/type    resolution control and introspection
exec [redirs] [cmd...]  set FDs or replace shell
source (.)              import file into current shell
return / exit           status control
```

## Special parameters

``` text
$0             script name
$1..$N         positional args
$#             arg count
"$@"           all args (each as separate word)
"$*"           all args as single word
$?             last exit status
${PIPESTATUS[@]}  exit codes from last pipeline
$$             PID of shell
$BASHPID      PID of current shell (even in subshell)
$PPID          parent PID
$LINENO        current line number
${BASH_SOURCE[@]}  source file stack
${FUNCNAME[@]}     function call stack
$BASH_COMMAND  command about to execute (in traps)
$BASH_SUBSHELL nesting depth
${BASH_REMATCH[@]}  regex capture groups from [[ =~ ]]
$SECONDS       seconds since shell start
$RANDOM        random 0-32767
$EPOCHREALTIME epoch with microseconds (Bash 5+)
```

## Grouping: current shell vs subshell

``` bash
{ list; }    # group in current shell (semicolon and spaces required)
( list )     # subshell: copy of variables, changes don't affect parent
```

## Quoting rules

- Double quotes `"..."`: allow `$var`, `$(...)`, `$((...))`, `\"`, `\\`
- Single quotes `'...'`: literal, no expansion
- `$'...'`: ANSI-C quoting (`\n`, `\t`, `\033[31m`, `\x1b`)
- Unquoted: word splitting + pathname expansion (avoid unless intended)
- Variables in `[[ ]]` don't need quotes but quote anyway for consistency
- Exception: `$?`, `$$`, boolean flags may remain unquoted
- Use `printf '%q'` or `${var@Q}` to shell-escape a value for safe reuse

## Expansion order

Brace -> tilde -> parameter -> command -> arithmetic -> word splitting -> pathname

## Shopt reference

``` text
extglob          extended globs: ?(pat) *(pat) +(pat) @(a|b) !(pat)
globstar         ** recursive directory matching
nullglob         no-match glob expands to nothing (not literal)
dotglob          globs include hidden files
failglob         no-match glob is an error
nocaseglob       case-insensitive globbing
lastpipe         last pipeline command runs in current shell
inherit_errexit  command substitutions respect set -e
globasciiranges  ranges use ASCII ordering
assoc_expand_once  associative array subscripts expanded once
```
