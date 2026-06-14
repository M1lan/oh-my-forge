package manifest

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

const (
	MLXWiredLimitGiB  uint64 = 14
	MLXMemoryLimitGiB uint64 = 18
	MLXCacheLimitGiB  uint64 = 2
)

// DefaultPath resolves the default location of the omf manifest:
// $HOME/forge/omf.toml. It is the single source of truth shared by the
// dispatcher and `omf doctor` so the two can never resolve different
// manifests. Falls back to a bare relative "omf.toml" only when the home
// directory is completely unresolvable.
func DefaultPath() string {
	if home := HomeDir(); home != "" {
		return filepath.Join(home, "forge", "omf.toml")
	}
	return "omf.toml"
}

// HomeDir returns the user's home directory, preferring os.UserHomeDir() and
// falling back to $HOME. Returns "" only when both are unavailable.
func HomeDir() string {
	if h, err := os.UserHomeDir(); err == nil && h != "" {
		return h
	}
	return os.Getenv("HOME")
}

type Kind string

const (
	KindForge    Kind = "forge"
	KindClaude   Kind = "claude"
	KindCodex    Kind = "codex"
	KindOmc      Kind = "omc"
	KindOmx      Kind = "omx"
	KindGemini   Kind = "gemini"
	KindCopilot  Kind = "copilot"
	KindVendor   Kind = "vendor"
	KindLocalLLM Kind = "local-llm"
)

type Routing string

const (
	RoutingNone    Routing = "none"
	RoutingWork    Routing = "work"
	RoutingPrivate Routing = "private"
)

type Manifest struct {
	SchemaVersion uint32
	Backends      []Backend
}

type Backend struct {
	Name          string
	Kind          Kind
	Routing       Routing
	Oneshot       []string
	Interactive   []string
	EnvAllowlist  []string
	DangerAllowed bool
	Limits        *Limits
}

type Limits struct {
	WiredGiB  uint64
	MemoryGiB uint64
	CacheGiB  uint64
}

type ClampLog struct {
	Backend   string
	Field     string
	Requested uint64
	ClampedTo uint64
}

func Parse(data []byte) (Manifest, error) {
	var m Manifest
	var current *Backend
	inLimits := false

	for lineNo, raw := range strings.Split(string(data), "\n") {
		line := stripComment(raw)
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		switch line {
		case "[[backend]]":
			m.Backends = append(m.Backends, Backend{})
			current = &m.Backends[len(m.Backends)-1]
			inLimits = false
			continue
		case "[backend.limits]":
			if current == nil {
				return Manifest{}, fmt.Errorf("line %d: backend.limits before backend", lineNo+1)
			}
			if current.Limits == nil {
				current.Limits = &Limits{}
			}
			inLimits = true
			continue
		}

		key, val, ok := strings.Cut(line, "=")
		if !ok {
			return Manifest{}, fmt.Errorf("line %d: expected key = value", lineNo+1)
		}
		key = strings.TrimSpace(key)
		val = strings.TrimSpace(val)

		if current == nil {
			if key != "schema_version" {
				return Manifest{}, fmt.Errorf("line %d: top-level key %q is not supported", lineNo+1, key)
			}
			n, err := parseUint(val)
			if err != nil {
				return Manifest{}, fmt.Errorf("line %d: schema_version: %w", lineNo+1, err)
			}
			m.SchemaVersion = uint32(n)
			continue
		}

		if inLimits {
			n, err := parseUint(val)
			if err != nil {
				return Manifest{}, fmt.Errorf("line %d: %s: %w", lineNo+1, key, err)
			}
			switch key {
			case "wired_gib":
				current.Limits.WiredGiB = n
			case "memory_gib":
				current.Limits.MemoryGiB = n
			case "cache_gib":
				current.Limits.CacheGiB = n
			default:
				return Manifest{}, fmt.Errorf("line %d: unsupported limits key %q", lineNo+1, key)
			}
			continue
		}

		switch key {
		case "name":
			s, err := parseString(val)
			if err != nil {
				return Manifest{}, fmt.Errorf("line %d: name: %w", lineNo+1, err)
			}
			current.Name = s
		case "kind":
			s, err := parseString(val)
			if err != nil {
				return Manifest{}, fmt.Errorf("line %d: kind: %w", lineNo+1, err)
			}
			kind := Kind(s)
			if !validKind(kind) {
				return Manifest{}, fmt.Errorf("line %d: unsupported kind %q", lineNo+1, s)
			}
			current.Kind = kind
		case "routing":
			s, err := parseString(val)
			if err != nil {
				return Manifest{}, fmt.Errorf("line %d: routing: %w", lineNo+1, err)
			}
			routing := Routing(s)
			if !validRouting(routing) {
				return Manifest{}, fmt.Errorf("line %d: unsupported routing %q", lineNo+1, s)
			}
			current.Routing = routing
		case "interactive":
			argv, err := parseStringArray(val)
			if err != nil {
				return Manifest{}, fmt.Errorf("line %d: interactive must be an argv array: %w", lineNo+1, err)
			}
			current.Interactive = argv
		case "oneshot":
			argv, err := parseStringArray(val)
			if err != nil {
				return Manifest{}, fmt.Errorf("line %d: oneshot must be an argv array: %w", lineNo+1, err)
			}
			current.Oneshot = argv
		case "env_allowlist":
			argv, err := parseStringArray(val)
			if err != nil {
				return Manifest{}, fmt.Errorf("line %d: env_allowlist must be an array: %w", lineNo+1, err)
			}
			for _, name := range argv {
				if isRoutingManagedEnv(name) {
					return Manifest{}, fmt.Errorf("line %d: env_allowlist %q is routing-managed", lineNo+1, name)
				}
			}
			current.EnvAllowlist = argv
		case "danger_allowed":
			b, err := strconv.ParseBool(val)
			if err != nil {
				return Manifest{}, fmt.Errorf("line %d: danger_allowed: %w", lineNo+1, err)
			}
			current.DangerAllowed = b
		default:
			return Manifest{}, fmt.Errorf("line %d: unsupported backend key %q", lineNo+1, key)
		}
	}

	for i, b := range m.Backends {
		if b.Name == "" {
			return Manifest{}, fmt.Errorf("backend %d: missing name", i)
		}
		if b.Kind == "" {
			return Manifest{}, fmt.Errorf("backend %q: missing kind", b.Name)
		}
	}
	if err := m.Validate(); err != nil {
		return Manifest{}, err
	}
	return m, nil
}

func isRoutingManagedEnv(name string) bool {
	return name == "HOME" || name == "FORGE_CONFIG"
}

func (m Manifest) Validate() error {
	seen := make(map[string]bool)
	for _, b := range m.Backends {
		if seen[b.Name] {
			return fmt.Errorf("backend %q: duplicate name", b.Name)
		}
		seen[b.Name] = true
		if b.Routing == "" {
			return fmt.Errorf("backend %q: missing routing", b.Name)
		}
		if !validRouting(b.Routing) {
			return fmt.Errorf("backend %q: unsupported routing %q", b.Name, b.Routing)
		}
		if b.Routing == RoutingNone && RequiresAccountRouting(b.Kind) {
			return fmt.Errorf("backend %q: kind %q cannot use routing=none", b.Name, b.Kind)
		}
		for _, name := range b.EnvAllowlist {
			if isRoutingManagedEnv(name) {
				return fmt.Errorf("backend %q: env_allowlist %q is routing-managed", b.Name, name)
			}
		}
	}
	return nil
}

func (m *Manifest) ClampAll() []ClampLog {
	var logs []ClampLog
	for i := range m.Backends {
		b := &m.Backends[i]
		if b.Limits == nil {
			continue
		}
		logs = append(logs, clampLimit(b.Name, "wired_gib", &b.Limits.WiredGiB, MLXWiredLimitGiB)...)
		logs = append(logs, clampLimit(b.Name, "memory_gib", &b.Limits.MemoryGiB, MLXMemoryLimitGiB)...)
		logs = append(logs, clampLimit(b.Name, "cache_gib", &b.Limits.CacheGiB, MLXCacheLimitGiB)...)
	}
	return logs
}

func clampLimit(backend, field string, val *uint64, floor uint64) []ClampLog {
	if *val <= floor {
		return nil
	}
	log := ClampLog{Backend: backend, Field: field, Requested: *val, ClampedTo: floor}
	*val = floor
	return []ClampLog{log}
}

func validKind(k Kind) bool {
	switch k {
	case KindForge, KindClaude, KindCodex, KindOmc, KindOmx, KindGemini, KindCopilot, KindVendor, KindLocalLLM:
		return true
	default:
		return false
	}
}

func RequiresAccountRouting(k Kind) bool {
	switch k {
	case KindVendor, KindLocalLLM:
		return false
	default:
		return true
	}
}

func validRouting(r Routing) bool {
	switch r {
	case RoutingNone, RoutingWork, RoutingPrivate:
		return true
	default:
		return false
	}
}

func stripComment(line string) string {
	inString := false
	escaped := false
	for i, r := range line {
		if escaped {
			escaped = false
			continue
		}
		if r == '\\' && inString {
			escaped = true
			continue
		}
		if r == '"' {
			inString = !inString
			continue
		}
		if r == '#' && !inString {
			return line[:i]
		}
	}
	return line
}

func parseString(val string) (string, error) {
	if len(val) < 2 || val[0] != '"' || val[len(val)-1] != '"' {
		return "", fmt.Errorf("expected quoted string")
	}
	return strconv.Unquote(val)
}

func parseUint(val string) (uint64, error) {
	return strconv.ParseUint(strings.TrimSpace(val), 10, 64)
}

func parseStringArray(val string) ([]string, error) {
	val = strings.TrimSpace(val)
	if len(val) < 2 || val[0] != '[' || val[len(val)-1] != ']' {
		return nil, fmt.Errorf("expected []")
	}
	body := strings.TrimSpace(val[1 : len(val)-1])
	if body == "" {
		return nil, nil
	}

	var out []string
	for len(body) > 0 {
		body = strings.TrimSpace(body)
		if !strings.HasPrefix(body, "\"") {
			return nil, fmt.Errorf("expected quoted array element near %q", body)
		}
		end := 1
		escaped := false
		for ; end < len(body); end++ {
			c := body[end]
			if escaped {
				escaped = false
				continue
			}
			if c == '\\' {
				escaped = true
				continue
			}
			if c == '"' {
				break
			}
		}
		if end >= len(body) || body[end] != '"' {
			return nil, fmt.Errorf("unterminated string")
		}
		s, err := strconv.Unquote(body[:end+1])
		if err != nil {
			return nil, err
		}
		out = append(out, s)
		body = strings.TrimSpace(body[end+1:])
		if body == "" {
			break
		}
		if body[0] != ',' {
			return nil, fmt.Errorf("expected comma near %q", body)
		}
		body = body[1:]
	}
	return out, nil
}

func LoadFile(path string) (Manifest, []ClampLog, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return Manifest{}, nil, err
	}
	m, err := Parse(data)
	if err != nil {
		return Manifest{}, nil, err
	}
	logs := m.ClampAll()
	return m, logs, nil
}
