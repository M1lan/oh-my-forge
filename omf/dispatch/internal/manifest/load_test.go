package manifest

import (
	"path/filepath"
	"testing"
)

func TestLoadFileParsesRepositoryManifest(t *testing.T) {
	m, logs, err := LoadFile(filepath.Join("..", "..", "..", "omf.toml"))
	if err != nil {
		t.Fatalf("LoadFile returned error: %v", err)
	}
	if len(logs) != 0 {
		t.Fatalf("clamp logs len = %d, want 0: %#v", len(logs), logs)
	}
	if len(m.Backends) < 2 {
		t.Fatalf("repository manifest backends len = %d, want at least 2", len(m.Backends))
	}
}
