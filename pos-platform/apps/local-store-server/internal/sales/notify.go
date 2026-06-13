package sales

// Notifier is what SaleService calls after a successful sale commit so the
// sync worker wakes immediately instead of waiting for its tick.
//
// The interface exists so SaleService doesn't import the sync package
// directly (and so tests can plug a counting fake). sync.Worker.Notify
// satisfies it implicitly.
type Notifier interface {
	Notify()
}

// NoopNotifier is a safe default when there's no worker wired in (tests,
// dry-runs). Calls are silently dropped.
type NoopNotifier struct{}

func (NoopNotifier) Notify() {}
