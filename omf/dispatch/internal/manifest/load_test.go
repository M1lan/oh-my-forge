package manifest

import (
	"os"
	"path/filepath"
	"testing"
)

func TestLoadFileParsesValidManifestFile(t *testing.T) {
	path := filepath.Join(t.TempDir(), "omf.toml")
	if err := os.WriteFile(path, []byte(`
schema_version = 0

[[backend]]
name = "forge"
kind = "forge"
routing = "private"
interactive = ["forge"]
env_allowlist = ["PATH"]
`), 0o644); err != nil {
		t.Fatalf("write fixture: %v", err)
	}

	m, logs, err := LoadFile(path)
	if err != nil {
		t.Fatalf("LoadFile returned error: %v", err)
	}
	if len(logs) != 0 {
		t.Fatalf("clamp logs len = %d, want 0: %#v", len(logs), logs)
	}
	if len(m.Backends) != 1 {
		t.Fatalf("manifest backends len = %d, want 1", len(m.Backends))
	}
}
