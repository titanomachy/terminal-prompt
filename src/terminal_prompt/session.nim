## Injectable prompt terminal-session lifecycle contract.

import std/options

import ./[io, keys, types]

type
  PromptSessionMode* = enum
    ## Rendering/input strategy selected for a prompt session.
    promptInteractiveMode
    promptLineMode

  PromptAnsiMode* = enum
    ## Controls ANSI output independently of backend capability detection.
    promptAnsiAuto
    promptAnsiAlways
    promptAnsiNever

  PromptCapabilities* = object
    ## Capabilities captured when a prompt session opens.
    inputIsTerminal*: bool
    outputIsTerminal*: bool
    supportsAnsi*: bool
    supportsRawMode*: bool
    supportsResizeEvents*: bool

  PromptSessionOptions* = object
    ## Backend-neutral options for opening a prompt session.
    rawMode*: bool
    hideCursor*: bool
    requireTerminal*: bool
    monitorResize*: bool
    ansiMode*: PromptAnsiMode
    escapeTimeoutMs*: int
    resizePollMs*: int

  PromptSession* = ref object of PromptIO
    ## Prompt I/O with capabilities, geometry, and guaranteed cleanup.

proc defaultPromptSessionOptions*(): PromptSessionOptions =
  ## Returns safe defaults that fall back when streams are not interactive.
  PromptSessionOptions(rawMode: true, hideCursor: false,
    requireTerminal: false, monitorResize: true, ansiMode: promptAnsiAuto,
    escapeTimeoutMs: 30, resizePollMs: 50)

proc selectSessionMode*(capabilities: PromptCapabilities;
                        options = defaultPromptSessionOptions()
                       ): PromptSessionMode =
  ## Selects interactive mode only when safe in-place input and output exist.
  if options.rawMode and capabilities.inputIsTerminal and
      capabilities.outputIsTerminal and capabilities.supportsRawMode and
      capabilities.supportsAnsi:
    promptInteractiveMode
  else:
    promptLineMode

method mode*(session: PromptSession): PromptSessionMode {.base.} =
  ## Returns the input/rendering strategy selected when the session opened.
  raise newException(PromptStateError,
    "mode is not implemented by this PromptSession")

method capabilities*(session: PromptSession): PromptCapabilities {.base.} =
  ## Returns capabilities captured when this session opened.
  raise newException(PromptStateError,
    "capabilities is not implemented by this PromptSession")

method terminalSize*(session: PromptSession): Option[PromptSize] {.base.} =
  ## Returns current terminal geometry when available.
  raise newException(PromptStateError,
    "terminalSize is not implemented by this PromptSession")

method close*(session: PromptSession) {.base.} =
  ## Restores all terminal state; repeated calls must be safe.
  raise newException(PromptStateError,
    "close is not implemented by this PromptSession")

template withPromptSession*(session: PromptSession; body: untyped): untyped =
  ## Runs ``body`` and closes ``session`` after normal return or an exception.
  try:
    body
  finally:
    session.close()
