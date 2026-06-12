# Code Patterns

Reusable patterns for common tasks. All require Bash 5.3+.

## Contents

- [Argument parsing](#argument-parsing)
- [Structured logging](#structured-logging)
- [Configuration file parsing](#configuration-file-parsing)
- [JSON processing](#json-processing)
- [CSV processing](#csv-processing)
- [Network operations](#network-operations)
- [Concurrency and locking](#concurrency-and-locking)
- [Performance timing](#performance-timing)
- [Retry with exponential backoff](#retry-with-exponential-backoff)
- [Circuit breaker](#circuit-breaker)
- [User interaction](#user-interaction)

## Argument parsing

Robust parsing with short-flag bundling and `--option=value` support:

``` bash
# validate that an option's value isn't blank or another flag
_require_value() {
  local opt=$1 val=${2:-}
  if [[ -z $val || $val == -* ]]; then
    printf 'error: %s requires a valid argument\n' "$opt" >&2
    return 2
  fi
  printf '%s' "$val"
}

parse_args() {
  local -A opts=()
  local -a positional=()

  opts[verbose]=0
  opts[dry_run]=0
  opts[help]=0

  while (( $# )); do
    case $1 in
      --output=*)   opts[output]=${1#*=} ;;
      --output|-o)  shift; opts[output]=$(_require_value --output "${1:-}") || return ;;
      --config=*)   opts[config]=${1#*=} ;;
      --config|-c)  shift; opts[config]=$(_require_value --config "${1:-}") || return ;;
      --verbose|-v) opts[verbose]=1 ;;
      --dry-run|-n) opts[dry_run]=1 ;;
      --help|-h)    opts[help]=1 ;;
      -[a-zA-Z]*)
        local bundle=${1#-} char
        for (( i=0; i<${#bundle}; i++ )); do
          char=${bundle:i:1}
          case $char in
            v) opts[verbose]=1 ;;
            n) opts[dry_run]=1 ;;
            h) opts[help]=1 ;;
            *) printf 'error: unknown flag: -%s\n' "$char" >&2; return 2 ;;
          esac
        done
        ;;
      --)  shift; positional+=("$@"); break ;;
      -*)  printf 'error: unknown option: %s\n' "$1" >&2; return 2 ;;
      *)   positional+=("$1") ;;
    esac
    shift
  done

  (( opts[verbose] )) && declare -gi VERBOSE=1
  (( opts[dry_run] )) && declare -gi DRY_RUN=1
  (( opts[help] )) && { show_help; exit 0; }

  declare -ga POSITIONAL=("${positional[@]}")
}
```

Alternative: portable `getopts` for simpler scripts:

``` bash
while getopts ':f:o:hv' opt; do
  case $opt in
    f) infile=$OPTARG ;;
    o) outfile=$OPTARG ;;
    h) usage; exit 0 ;;
    v) verbose=1 ;;
    \?) printf 'unknown option: -%s\n' "$OPTARG" >&2; exit 2 ;;
    :)  printf 'missing arg for -%s\n' "$OPTARG" >&2; exit 2 ;;
  esac
done
shift $((OPTIND-1))
```

## Structured logging

``` bash
declare -A LOG_LEVELS=([DEBUG]=0 [INFO]=1 [WARN]=2 [ERROR]=3)
declare -i LOG_LEVEL=${LOG_LEVELS[INFO]}

# level - DEBUG|INFO|WARN|ERROR
# message - log message

log() {
  local level=$1 message=$2
  local -i level_num=${LOG_LEVELS[$level]:-1}
  (( level_num >= LOG_LEVEL )) || return 0
  printf '[%(%Y-%m-%d %H:%M:%S)T] %s: %s\n' -1 "$level" "$message" >&2
}
```

## Configuration file parsing

Parses `key=value` files, skips comments and blanks:

``` bash

# config_file - path to config
# config_ref - nameref to associative array

parse_config() {
  local config_file=$1
  local -n config_ref=$2
  local line key value

  while IFS= read -r line || [[ -n $line ]]; do
    [[ $line =~ ^[[:space:]]*# ]] && continue
    [[ $line =~ ^[[:space:]]*$ ]] && continue
    if [[ $line =~ ^([^=]+)=(.*)$ ]]; then
      key=${BASH_REMATCH[1]// /}
      value=${BASH_REMATCH[2]}
      config_ref[$key]=$value
    fi
  done < "$config_file"
}
```

## JSON processing

### With jq (complex JSON)

``` bash

# json_file - input file
# result_ref - nameref to associative array

process_json() {
  local json_file=$1
  local -n result_ref=$2
  local key value
  while IFS=$'\t' read -r key value; do
    result_ref[$key]=$value
  done < <(jq -r 'to_entries[] | [.key, .value] | @tsv' "$json_file")
}
```

### Pure Bash (flat key-value only, no jq dependency)

``` bash

# extracts string values from flat JSON
# json - raw JSON string
# key - key name to extract

json_val() {
  local json=$1 key=$2
  if [[ $json =~ \"${key}\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
  else
    printf '%s' "?"
  fi
}
```

Limitations: strings only, no escaped quotes, first occurrence. Use jq for
anything complex.

## CSV processing

``` bash

# csv_file - input CSV
# callback_func - function(headers_ref, row_ref, line_num)

process_csv() {
  local csv_file=$1 callback_func=$2
  local -a headers row
  local -i line_num=0

  { IFS=',' read -ra headers
    (( ${#headers[@]} > 0 )) || { log ERROR "no headers in csv"; return 1; }
  } < "$csv_file"

  while IFS=',' read -ra row; do
    (( ++line_num ))
    if (( ${#row[@]} != ${#headers[@]} )); then
      log WARN "line $line_num: column count mismatch"
      continue
    fi
    "$callback_func" headers row "$line_num"
  done < <(tail -n +2 "$csv_file")
}
```

## Network operations

### Using /dev/tcp (no curl dependency)

``` bash

# host - target hostname
# port - target port
# path - HTTP path

http_get() {
  local host=$1 port=$2 path=$3

  if ! exec 3<>"/dev/tcp/$host/$port" 2>/dev/null; then
    log ERROR "connect failed: $host:$port"
    return 1
  fi

  printf 'GET %s HTTP/1.1\r\nHost: %s\r\nConnection: close\r\n\r\n' \
    "$path" "$host" >&3
  cat <&3
  exec 3<&-
}
```

Check availability: `[[ -e /dev/tcp/localhost/1 ]] 2>/dev/null` -- not all Bash
builds support it.

## Concurrency and locking

``` bash
acquire_lock() {
  local lockfile=$1 timeout=${2:-10}
  local -i attempts=0

  if command -v flock >/dev/null; then
    exec 200>"$lockfile"
    if ! flock -n 200; then
      printf 'waiting for lock: %s\n' "$lockfile" >&2
      flock -w "$timeout" 200 || {
        printf 'timeout waiting for lock: %s\n' "$lockfile" >&2
        return 1
      }
    fi
  else
    while ! ln "$0" "$lockfile" 2>/dev/null; do
      if (( attempts++ >= timeout )); then
        printf 'timeout waiting for lock: %s\n' "$lockfile" >&2
        return 1
      fi
      sleep 1
    done
    trap "rm -f '$lockfile'" EXIT
  fi
}

release_lock() {
  local lockfile=$1
  if command -v flock >/dev/null; then
    exec 200>&-
  fi
  rm -f "$lockfile"
}
```

## Performance timing

``` bash

# usage: with_timing my_func args...

with_timing() {
  local -r _t0=${EPOCHREALTIME}
  "$@"; local _rc=$?
  local -r _t1=${EPOCHREALTIME}
  printf 'duration_ms=%d\n' "$(( (10#${_t1/.} - 10#${_t0/.}) / 1000 ))" >&2
  return "$_rc"
}
```

## Retry with exponential backoff

``` bash

# max_attempts - maximum retry count
# base_delay - initial delay in seconds
# max_delay - delay cap in seconds
# remaining args - command to execute

retry_with_backoff() {
  local -i max_attempts=$1 base_delay=$2 max_delay=$3
  shift 3

  local -i attempt=1 delay=$base_delay

  while (( attempt <= max_attempts )); do
    printf 'attempt %d/%d: %s\n' "$attempt" "$max_attempts" "$*" >&2

    if "$@"; then
      printf 'success on attempt %d\n' "$attempt" >&2
      return 0
    fi

    if (( attempt == max_attempts )); then
      printf 'all %d attempts failed\n' "$max_attempts" >&2
      return 1
    fi

    printf 'failed, retrying in %ds...\n' "$delay" >&2
    sleep "$delay"

    # exponential backoff with jitter
    (( delay *= 2 ))
    (( delay > max_delay )) && delay=$max_delay
    local -i jitter=$(( delay / 5 ))
    (( jitter > 0 )) && (( delay += (RANDOM % (jitter * 2)) - jitter ))

    (( attempt++ ))
  done
}

# usage:
# retry_with_backoff 5 2 30 curl -f "https://api.example.com/health"
# retry_with_backoff 3 1 10 docker pull "$IMAGE"

```

## Circuit breaker

Stops hammering services that are down:

``` bash
declare -A CIRCUIT_BREAKERS=()

# service - service identifier
# failure_threshold - failures before opening (default 5)
# reset_timeout - seconds before retry (default 300)

is_circuit_open() {
  local service=$1
  local -i failure_threshold=${2:-5} reset_timeout=${3:-300}
  local cb_data=${CIRCUIT_BREAKERS[$service]:-}
  [[ -z $cb_data ]] && return 1

  local -i failures=${cb_data%%:*}
  local -i last_failure=${cb_data##*:}
  local -i now=${EPOCHSECONDS}

  if (( now - last_failure > reset_timeout )); then
    unset 'CIRCUIT_BREAKERS[$service]'
    return 1
  fi
  (( failures >= failure_threshold ))
}

record_failure() {
  local service=$1
  local cb_data=${CIRCUIT_BREAKERS[$service]:-}
  if [[ -z $cb_data ]]; then
    CIRCUIT_BREAKERS[$service]="1:${EPOCHSECONDS}"
  else
    local -i failures=${cb_data%%:*}
    CIRCUIT_BREAKERS[$service]="$(( failures + 1 )):${EPOCHSECONDS}"
  fi
}

# service - service name
# remaining args - command to call

call_with_circuit_breaker() {
  local service=$1; shift
  if is_circuit_open "$service"; then
    printf 'circuit open for %s, skipping\n' "$service" >&2
    return 1
  fi
  if "$@"; then
    return 0
  else
    record_failure "$service"
    return 1
  fi
}

# usage:
# call_with_circuit_breaker "payment_api" curl -f "https://payment.api.com/process"

```

## User interaction

``` bash

# colored output helpers

Important: always prefer using 'tput' instead of ANSI escape codes!
#TODO: update these examples to use tput
RED=$'\033[31m'  GREEN=$'\033[32m'  YELLOW=$'\033[33m'
CYAN=$'\033[36m' BOLD=$'\033[1m'    DIM=$'\033[2m'
RESET=$'\033[0m'

log()  { printf '%s %s\n' "${CYAN}>>>${RESET}" "$*"; }
warn() { printf '%s %s\n' "${YELLOW}!!!${RESET}" "$*"; }
err()  { printf '%s %s\n' "${RED}***${RESET}" "$*" >&2; }
ok()   { printf '%s %s\n' "${GREEN}+++${RESET}" "$*"; }
hr()   { printf '%s\n' "${DIM}$(printf '%.0s-' {1..79})${RESET}"; }

# confirm gate (default N = safe)

confirm() {
  local prompt=$1 reply
  printf '\n%s [y/N] ' "${BOLD}${prompt}${RESET}"
  read -r reply
  [[ ${reply,,} == y ]]
}
```

Use `$'\033[..m'` not `\e[..m` (portable). Use `printf` not `echo`.
