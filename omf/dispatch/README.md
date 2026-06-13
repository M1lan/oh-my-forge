# omf dispatcher deployment model

The Go dispatcher does **not** change Unix uid/gid. Its `syscall.Exec` and
`exec.Command` paths run children as the uid that launched `omf`. Therefore the
OS account is the hard security boundary: launch private routes from the private
login account and work routes from the work login account.

`HOME`, `FORGE_CONFIG`, and the fail-closed environment plan are defense in
depth for configuration routing; they do not make a same-uid child unable to
read files by absolute path. Do not deploy `omf` as a single privileged or
shared-uid service for multiple accounts. If cross-account launching becomes a
requirement, add and review an explicit credential-switching layer before first
use.
