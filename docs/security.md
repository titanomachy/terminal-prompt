# Security guidance

TerminalPrompt prevents password text from being echoed by its own prompt
renderer. In interactive mode it displays only the configured mask (or no
feedback); in line mode it still omits the answer. Password results also print
`[redacted]` through `$`.

These protections are deliberately narrow. A caller can access `.value`, and
ordinary Nim strings may be copied and are not guaranteed to be zeroed after
use. TerminalPrompt is not a secure-memory or credential-storage library.

## Application responsibilities

- Never log, echo, format, or attach a password result value to an exception.
- Prefer an empty mask when even password length is sensitive.
- Keep secrets out of command-line arguments and environment dumps.
- Send credentials only to their intended destination over an authenticated,
  encrypted channel.
- Avoid collecting passwords from redirected input when another process or
  file could expose that input. TerminalPrompt cannot change source-file
  permissions or shell history.
- Keep validators side-effect-free and return generic messages.

Password validator messages have exact occurrences of the submitted value
replaced by `[redacted]`. This cannot detect transformed, encoded, hashed,
partially copied, or otherwise derived secrets. If a password validator raises
a catchable exception, TerminalPrompt discards its message and parent chain and
raises a generic `PromptError` after restoring the display and terminal.

Cancellation, EOF, and I/O failures do not render the partially entered
password. TerminalScreen owns raw-mode and cursor restoration; TerminalPrompt
closes its display and session from `finally` on every library-controlled exit
path. Process termination that cannot run cleanup (for example `SIGKILL`, a
power loss, or a runtime abort) is outside this guarantee.

When reporting a security issue, follow the repository's private security
reporting channel if one is configured. Never include real credentials in a
bug report, test fixture, terminal capture, or CI log.
