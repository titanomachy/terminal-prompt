# Compatibility and performance

## Supported environments

TerminalPrompt supports Nim 2.0.0 and newer. CI runs the Nim 2.0 release line
and the current stable compiler on Linux, macOS, and Windows with the default
memory manager. Stable Nim/Linux additionally runs the portable test suite
under ARC and ORC. POSIX jobs also exercise pseudo-terminal integration; all
platforms run deterministic session, prompt, redirected-stream, Unicode,
narrow-terminal, and resize tests.

Terminal behavior is capability-driven rather than OS-name-driven. Full
interactive mode requires terminal input and output plus raw-input and ANSI
support. Any missing capability selects line mode, including redirected
stdin/stdout and ANSI-disabled terminals. `TERM=dumb` is treated as limited.

Unicode editing and truncation use TerminalStyle's terminal-cell model. Actual
glyph shape and width can still vary with terminal emulator, font, Unicode
version, locale, and platform console configuration. Labels remain valid UTF-8
and are truncated only at terminal-grapheme boundaries.

## Large selection lists

Interactive selection renders only rows in the current terminal-height
viewport. State and validation remain linear in the number of choices, while
each navigation redraw is bounded by visible rows. Line mode intentionally
prints the complete numbered list because cursor-based navigation is
unavailable.

Run the repeatable release-mode benchmark with:

```sh
nimble benchmark
```

It constructs 100, 1,000, 10,000, and 100,000 typed choices, opens a scripted
80×24 interactive session, moves once, and submits. The benchmark reports CPU
time and asserts the selected answer; it does not enforce a timing threshold
because CI hosts and compilers vary substantially.

For a non-normative baseline, a Linux development run with Nim 2.2.10 measured
0.43 ms, 2.96 ms, 33.57 ms, and 344.71 ms respectively. These numbers include
option validation, initial rendering, one navigation redraw, submission, and
cleanup; they are evidence for the 0.1.0 decision, not a performance guarantee.

Filtering is intentionally deferred for 0.1.0. It would add query editing,
match semantics, focus restoration, and new line-mode contracts to a one-shot
selection API. The viewport keeps rendering bounded, and the benchmark makes
the remaining linear setup cost visible. Filtering should be reconsidered if
real applications demonstrate problematic setup/navigation latency or an
unusable discovery experience, with representative labels and list sizes
added to the benchmark first.
