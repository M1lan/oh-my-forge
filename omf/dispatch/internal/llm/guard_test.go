package llm

import (
	"context"
	"errors"
	"net/http"
	"testing"

	"omf/dispatch/internal/omfcore"
)

type fakeGuard struct {
	admitErr  error
	lockFree  bool
	lockErr   error
	admitCall bool
	lockCall  bool
	peakGiB   uint64
	budgetGiB uint64
}

func (f *fakeGuard) GuardAdmit(_ context.Context, peakGiB, budgetGiB uint64, _ bool) error {
	f.admitCall = true
	f.peakGiB = peakGiB
	f.budgetGiB = budgetGiB
	return f.admitErr
}

func (f *fakeGuard) GuardLockFree(_ context.Context, _ string) (bool, error) {
	f.lockCall = true
	return f.lockFree, f.lockErr
}

func warmupClient(t *testing.T, guard Guard) (*Client, *recordingTransport) {
	t.Helper()
	transport := &recordingTransport{responses: map[string]string{
		"POST http://llama/v1/chat/completions": `{"id":"warmup","choices":[]}`,
	}}
	client := NewClient(Config{
		LlamaSwapURL: "http://llama",
		HTTPClient:   &http.Client{Transport: transport},
		BudgetsGiB:   map[string]uint64{"fits": 9},
		MaxGiB:       14,
		Guard:        guard,
	})
	return client, transport
}

func TestLoadGuardAdmitsAndWarmsModel(t *testing.T) {
	guard := &fakeGuard{lockFree: true}
	client, transport := warmupClient(t, guard)
	if err := client.Load(context.Background(), "fits"); err != nil {
		t.Fatalf("Load returned error: %v", err)
	}
	if !guard.lockCall || !guard.admitCall {
		t.Fatalf("guard not consulted: lock=%v admit=%v", guard.lockCall, guard.admitCall)
	}
	if guard.peakGiB != 9 || guard.budgetGiB != 14 {
		t.Fatalf("guard admit args = peak %d budget %d, want 9/14", guard.peakGiB, guard.budgetGiB)
	}
	if len(transport.calls) != 1 {
		t.Fatalf("calls = %#v, want one warmup POST", transport.calls)
	}
}

func TestLoadGuardRefusalBlocksWarmup(t *testing.T) {
	guard := &fakeGuard{lockFree: true, admitErr: omfcore.ErrRefused}
	client, transport := warmupClient(t, guard)
	err := client.Load(context.Background(), "fits")
	if !errors.Is(err, omfcore.ErrRefused) {
		t.Fatalf("err = %T %[1]v, want ErrRefused", err)
	}
	if len(transport.calls) != 0 {
		t.Fatalf("refused load still made HTTP calls: %#v", transport.calls)
	}
}

func TestLoadGuardHeldLockBlocksWarmup(t *testing.T) {
	guard := &fakeGuard{lockFree: false}
	client, transport := warmupClient(t, guard)
	err := client.Load(context.Background(), "fits")
	if !errors.Is(err, ErrLoadInFlight) {
		t.Fatalf("err = %T %[1]v, want ErrLoadInFlight", err)
	}
	if guard.admitCall {
		t.Fatal("admit consulted while lock was held; should short-circuit")
	}
	if len(transport.calls) != 0 {
		t.Fatalf("in-flight load still made HTTP calls: %#v", transport.calls)
	}
}

func TestLoadGuardUnavailableProceedsUnguarded(t *testing.T) {
	guard := &fakeGuard{lockErr: omfcore.ErrUnavailable}
	client, transport := warmupClient(t, guard)
	if err := client.Load(context.Background(), "fits"); err != nil {
		t.Fatalf("Load returned error: %v", err)
	}
	if len(transport.calls) != 1 {
		t.Fatalf("calls = %#v, want one warmup POST (unavailable guard => skip)", transport.calls)
	}
}

func TestLoadWithoutGuardProceeds(t *testing.T) {
	client, transport := warmupClient(t, nil)
	if err := client.Load(context.Background(), "fits"); err != nil {
		t.Fatalf("Load returned error: %v", err)
	}
	if len(transport.calls) != 1 {
		t.Fatalf("calls = %#v, want one warmup POST", transport.calls)
	}
}
