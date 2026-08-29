## Injectable prompt input/output contract.

import ./[keys, types]

type PromptIO* = ref object of RootObj
  ## Bidirectional I/O used by prompt engines.
  ##
  ## Production code uses the TerminalScreen adapter. Tests can subclass this
  ## type to provide scripted input and captured output without stdin/stdout.

method readEvent*(io: PromptIO; timeoutMs = -1): PromptInputEvent {.base.} =
  ## Reads one normalized event.
  raise newException(PromptStateError,
    "readEvent is not implemented by this PromptIO")

method write*(io: PromptIO; value: string) {.base.} =
  ## Writes prompt output without implicitly adding a newline.
  raise newException(PromptStateError, "write is not implemented by this PromptIO")

method flush*(io: PromptIO) {.base.} =
  ## Flushes pending output.
  raise newException(PromptStateError, "flush is not implemented by this PromptIO")
