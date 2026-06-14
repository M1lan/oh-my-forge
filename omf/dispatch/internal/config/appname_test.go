package config

import (
	"os"
	"testing"
)

func TestAppName_Default(t *testing.T) {
	// Clear env var to test default
	old := os.Getenv("OMF_APP_NAME")
	defer os.Setenv("OMF_APP_NAME", old)
	os.Unsetenv("OMF_APP_NAME")

	if got := AppName(); got != DefaultAppName {
		t.Errorf("AppName() = %q, want %q", got, DefaultAppName)
	}
}

func TestAppName_EnvOverride(t *testing.T) {
	old := os.Getenv("OMF_APP_NAME")
	defer os.Setenv("OMF_APP_NAME", old)

	os.Setenv("OMF_APP_NAME", "omf")
	if got := AppName(); got != "omf" {
		t.Errorf("AppName() = %q, want %q", got, "omf")
	}

	os.Setenv("OMF_APP_NAME", "custom-app")
	if got := AppName(); got != "custom-app" {
		t.Errorf("AppName() = %q, want %q", got, "custom-app")
	}
}

func TestAppName_EmptyEnvFallsBack(t *testing.T) {
	old := os.Getenv("OMF_APP_NAME")
	defer os.Setenv("OMF_APP_NAME", old)

	os.Setenv("OMF_APP_NAME", "")
	if got := AppName(); got != DefaultAppName {
		t.Errorf("AppName() = %q, want %q (empty env should fall back)", got, DefaultAppName)
	}
}
