package mlx

import (
	"context"
	"errors"
	"fmt"
	"os"
	"regexp"
	"strconv"
	"strings"

	"omf/dispatch/internal/llm"
	"omf/dispatch/internal/manifest"
)

const (
	DefaultWrapperPath         = "/Users/milan.santosi/.local/bin/mlx_lm_server_safe"
	DefaultLlamaSwapConfigPath = "/Users/milan.santosi/.config/llama-swap/config.yaml"
	DefaultModelID             = "/Users/milan.santosi/qwen36-mlx"
	DefaultModelAlias          = "qwen36-mlx"
)

type Caps struct {
	WiredGiB  uint64
	MemoryGiB uint64
	CacheGiB  uint64
}

type Report struct {
	WrapperPath       string
	LlamaSwapPath     string
	ModelID           string
	Caps              Caps
	UsesWrapper       bool
	GroupSwap         bool
	GroupExclusive    bool
	GroupMember       bool
	PromptCacheBytes  uint64
	HasNoSuspension   bool
	CheckEndpoint     string
	LlamaSwapModelCmd string
}

type LLM interface {
	Load(context.Context, string) error
}

type Manager struct {
	WrapperPath         string
	LlamaSwapConfigPath string
	ReadFile            func(string) ([]byte, error)
	LLM                 LLM
}

type DriftError struct{ Message string }

func (e DriftError) Error() string { return e.Message }

func IsDriftError(err error) bool {
	var drift DriftError
	return errors.As(err, &drift)
}

func (m Manager) Inspect(_ context.Context, model string) (Report, error) {
	wrapperPath := m.wrapperPath()
	configPath := m.configPath()
	modelID := resolveModel(model)

	wrapperData, err := m.readFile(wrapperPath)
	if err != nil {
		return Report{}, err
	}
	configData, err := m.readFile(configPath)
	if err != nil {
		return Report{}, err
	}

	caps, err := inspectWrapper(string(wrapperData))
	if err != nil {
		return Report{}, err
	}
	entry, err := inspectConfig(string(configData), wrapperPath, modelID)
	if err != nil {
		return Report{}, err
	}
	return Report{
		WrapperPath:       wrapperPath,
		LlamaSwapPath:     configPath,
		ModelID:           modelID,
		Caps:              caps,
		UsesWrapper:       entry.usesWrapper,
		GroupSwap:         entry.groupSwap,
		GroupExclusive:    entry.groupExclusive,
		GroupMember:       entry.groupMember,
		PromptCacheBytes:  entry.promptCacheBytes,
		HasNoSuspension:   entry.hasNoSuspension,
		CheckEndpoint:     entry.checkEndpoint,
		LlamaSwapModelCmd: entry.modelBlock,
	}, nil
}

func (m Manager) Load(ctx context.Context, model string) (Report, error) {
	report, err := m.Inspect(ctx, model)
	if err != nil {
		return Report{}, err
	}
	client := m.LLM
	if client == nil {
		client = llm.NewClient(llm.Config{})
	}
	if err := client.Load(ctx, report.ModelID); err != nil {
		return Report{}, err
	}
	return report, nil
}

func (m Manager) wrapperPath() string {
	if m.WrapperPath != "" {
		return m.WrapperPath
	}
	return DefaultWrapperPath
}

func (m Manager) configPath() string {
	if m.LlamaSwapConfigPath != "" {
		return m.LlamaSwapConfigPath
	}
	return DefaultLlamaSwapConfigPath
}

func (m Manager) readFile(path string) ([]byte, error) {
	if m.ReadFile != nil {
		return m.ReadFile(path)
	}
	return os.ReadFile(path)
}

func resolveModel(model string) string {
	switch strings.TrimSpace(model) {
	case "", DefaultModelAlias, DefaultModelID:
		return DefaultModelID
	default:
		return model
	}
}

func inspectWrapper(wrapper string) (Caps, error) {
	caps := Caps{
		WiredGiB:  parseGiBAssignment(wrapper, "WIRED_CAP"),
		MemoryGiB: parseGiBAssignment(wrapper, "MEM_LIMIT"),
		CacheGiB:  parseGiBAssignment(wrapper, "CACHE_LIMIT"),
	}
	if caps.WiredGiB == 0 || caps.MemoryGiB == 0 || caps.CacheGiB == 0 {
		return Caps{}, DriftError{Message: "mlx wrapper caps are missing"}
	}
	if caps.WiredGiB > manifest.MLXWiredLimitGiB || caps.MemoryGiB > manifest.MLXMemoryLimitGiB || caps.CacheGiB > manifest.MLXCacheLimitGiB {
		return Caps{}, DriftError{Message: fmt.Sprintf("mlx wrapper caps exceed floor: %#v", caps)}
	}
	required := []string{
		"mx.set_wired_limit = _clamped_set_wired_limit",
		"mx.set_memory_limit(MEM_LIMIT)",
		"mx.set_cache_limit(CACHE_LIMIT)",
		"from mlx_lm.server import main",
	}
	for _, token := range required {
		if !strings.Contains(wrapper, token) {
			return Caps{}, DriftError{Message: fmt.Sprintf("mlx wrapper missing %q", token)}
		}
	}
	return caps, nil
}

func parseGiBAssignment(text, name string) uint64 {
	re := regexp.MustCompile(`(?m)^\s*` + regexp.QuoteMeta(name) + `\s*=\s*(\d+)\s*\*\s*GiB\s*$`)
	match := re.FindStringSubmatch(text)
	if len(match) != 2 {
		return 0
	}
	n, _ := strconv.ParseUint(match[1], 10, 64)
	return n
}

type configEntry struct {
	usesWrapper      bool
	groupSwap        bool
	groupExclusive   bool
	groupMember      bool
	promptCacheBytes uint64
	hasNoSuspension  bool
	checkEndpoint    string
	modelBlock       string
}

func inspectConfig(config, wrapperPath, modelID string) (configEntry, error) {
	macroPath, ok := parseQuotedScalar(config, "mlx-server")
	if !ok {
		return configEntry{}, DriftError{Message: "llama-swap mlx-server macro is missing"}
	}
	if macroPath != wrapperPath {
		return configEntry{}, DriftError{Message: fmt.Sprintf("llama-swap mlx-server macro points at %q, want %q", macroPath, wrapperPath)}
	}

	block, ok := modelBlock(config, modelID)
	if !ok {
		return configEntry{}, DriftError{Message: fmt.Sprintf("llama-swap model entry %q is missing", modelID)}
	}
	entry := configEntry{
		usesWrapper:      strings.Contains(block, "${mlx-server}"),
		groupSwap:        hasScalarTrue(config, "swap"),
		groupExclusive:   hasScalarTrue(config, "exclusive"),
		groupMember:      strings.Contains(config, `- "`+modelID+`"`),
		promptCacheBytes: parseFlagUint(block, "--prompt-cache-bytes"),
		hasNoSuspension:  !containsSuspension(block),
		checkEndpoint:    parseBlockQuotedScalar(block, "checkEndpoint"),
		modelBlock:       block,
	}
	if !entry.usesWrapper {
		return configEntry{}, DriftError{Message: "llama-swap model entry does not use ${mlx-server}"}
	}
	if containsRawServer(block) {
		return configEntry{}, DriftError{Message: "llama-swap model entry reinvents raw mlx_lm.server"}
	}
	if !entry.hasNoSuspension {
		return configEntry{}, DriftError{Message: "llama-swap model entry attempts process suspension"}
	}
	if entry.promptCacheBytes == 0 || entry.promptCacheBytes > manifest.MLXCacheLimitGiB<<30 {
		return configEntry{}, DriftError{Message: fmt.Sprintf("prompt cache bytes %d exceed cap", entry.promptCacheBytes)}
	}
	if entry.checkEndpoint != "/v1/models" {
		return configEntry{}, DriftError{Message: fmt.Sprintf("checkEndpoint = %q, want /v1/models", entry.checkEndpoint)}
	}
	if !entry.groupSwap || !entry.groupExclusive || !entry.groupMember {
		return configEntry{}, DriftError{Message: "llama-swap llm group is not swap+exclusive or is missing the MLX member"}
	}
	return entry, nil
}

func parseQuotedScalar(text, key string) (string, bool) {
	re := regexp.MustCompile(`(?m)^\s*` + regexp.QuoteMeta(key) + `\s*:\s*"([^"]+)"\s*$`)
	match := re.FindStringSubmatch(text)
	if len(match) != 2 {
		return "", false
	}
	return match[1], true
}

func parseBlockQuotedScalar(block, key string) string {
	value, ok := parseQuotedScalar(block, key)
	if !ok {
		return ""
	}
	return value
}

func hasScalarTrue(text, key string) bool {
	re := regexp.MustCompile(`(?m)^\s*` + regexp.QuoteMeta(key) + `\s*:\s*true\s*$`)
	return re.MatchString(text)
}

func modelBlock(config, modelID string) (string, bool) {
	lines := strings.Split(config, "\n")
	start := -1
	needle := `"` + modelID + `":`
	for i, line := range lines {
		if strings.TrimSpace(line) == needle {
			start = i
			break
		}
	}
	if start < 0 {
		return "", false
	}
	end := len(lines)
	for i := start + 1; i < len(lines); i++ {
		line := lines[i]
		if strings.HasPrefix(line, "  \"") && strings.HasSuffix(strings.TrimSpace(line), ":") {
			end = i
			break
		}
		if strings.TrimSpace(line) == "groups:" {
			end = i
			break
		}
	}
	return strings.Join(lines[start:end], "\n"), true
}

func parseFlagUint(block, flag string) uint64 {
	re := regexp.MustCompile(regexp.QuoteMeta(flag) + `\s+(\d+)`)
	match := re.FindStringSubmatch(block)
	if len(match) != 2 {
		return 0
	}
	n, _ := strconv.ParseUint(match[1], 10, 64)
	return n
}

func containsRawServer(block string) bool {
	return strings.Contains(block, "mlx_lm.server")
}

func containsSuspension(block string) bool {
	for _, token := range []string{"SIGSTOP", "SIGTSTP", "kill -STOP", "pkill -STOP", "suspend"} {
		if strings.Contains(block, token) {
			return true
		}
	}
	return false
}
