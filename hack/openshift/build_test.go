package openshift

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestBuild(t *testing.T) {
	script, err := filepath.Abs("build.sh")
	if err != nil {
		t.Fatal(err)
	}
	for _, tt := range []struct {
		name      string
		args      []string
		platforms []string
		wantError bool
	}{
		{name: "default", platforms: []string{"linux/amd64", "linux/arm64", "linux/ppc64le", "linux/s390x", "darwin/amd64", "darwin/arm64", "windows/amd64"}},
		{name: "all", args: []string{"--all"}, platforms: []string{"linux/amd64", "linux/arm64", "linux/ppc64le", "linux/s390x", "darwin/amd64", "darwin/arm64", "windows/amd64"}},
		{name: "platform", args: []string{"--platform", "darwin", "arm64"}, platforms: []string{"darwin/arm64"}},
		{name: "windows", args: []string{"-p", "windows", "amd64"}, platforms: []string{"windows/amd64"}},
		{name: "help", args: []string{"--help"}},
		{name: "missing architecture", args: []string{"-p", "linux"}, wantError: true},
		{name: "unsupported platform", args: []string{"-p", "windows", "arm64"}, wantError: true},
		{name: "extra argument", args: []string{"--all", "extra"}, wantError: true},
		{name: "unknown flag", args: []string{"--unknown"}, wantError: true},
	} {
		t.Run(tt.name, func(t *testing.T) {
			dir := t.TempDir()
			log := filepath.Join(dir, "build.log")
			// Record the environment and each argument separately so the test
			// detects incorrectly quoted linker flags as well as wrong targets.
			mock := "#!/usr/bin/env bash\nprintf '%s\\n' \"$PWD\" \"$CGO_ENABLED/$GOOS/$GOARCH\" \"$@\" >> \"$BUILD_LOG\"\n"
			if err := os.WriteFile(filepath.Join(dir, "go"), []byte(mock), 0o755); err != nil {
				t.Fatal(err)
			}
			cmd := exec.Command("bash", append([]string{script}, tt.args...)...)
			cmd.Dir = dir // The script must work from outside the checkout.
			cmd.Env = append(os.Environ(), "PATH="+dir+string(os.PathListSeparator)+os.Getenv("PATH"),
				"BUILD_LOG="+log, "VERS=test-version", "KVER=test-knative", "HASH=test-hash", "FUNC_UTILS_IMG=example.com/utils:test")
			output, err := cmd.CombinedOutput()
			if (err != nil) != tt.wantError {
				t.Fatalf("build error = %v, wantError = %v; output: %s", err, tt.wantError, output)
			}
			data, err := os.ReadFile(log)
			if len(tt.platforms) == 0 {
				if !os.IsNotExist(err) {
					t.Fatalf("expected no go invocation, log: %s, error: %v", data, err)
				}
				return
			}
			if err != nil {
				t.Fatal(err)
			}
			root := filepath.Clean(filepath.Join(filepath.Dir(script), "../.."))
			flags := "-w -s -X knative.dev/func/pkg/version.Vers=test-version" +
				" -X knative.dev/func/pkg/version.Kver=test-knative -X knative.dev/func/pkg/version.Hash=test-hash" +
				" -X knative.dev/func/pkg/k8s.SocatImage=example.com/utils:test" +
				" -X knative.dev/func/pkg/k8s.TarImage=example.com/utils:test" +
				" -X knative.dev/func/pkg/pipelines/tekton.FuncUtilImage=example.com/utils:test"
			var want strings.Builder
			for _, platform := range tt.platforms {
				binary := "func_" + strings.ReplaceAll(platform, "/", "_")
				if strings.HasPrefix(platform, "windows/") {
					binary += ".exe"
				}
				want.WriteString(strings.Join([]string{root, "0/" + platform, "build", "-trimpath", "-ldflags", flags, "-o", binary, "./cmd/func", ""}, "\n"))
			}
			if string(data) != want.String() {
				t.Fatalf("unexpected build commands:\n%s\nwant:\n%s", data, want.String())
			}
		})
	}
}
