## Deterministic prompt session and output capture for unit tests.

import std/options

import terminal_prompt/[keys, session, types]

type ScriptedSession* = ref object of PromptSession
  events*: seq[PromptInputEvent]
  nextEvent*: int
  output*: string
  flushCount*: int
  closeCount*: int
  selectedMode*: PromptSessionMode
  detectedCapabilities*: PromptCapabilities
  detectedSize*: Option[PromptSize]
  failRead*: bool
  failWrite*: bool
  failFlush*: bool
  failClose*: bool
  closed*: bool

proc newScriptedSession*(events: sink seq[PromptInputEvent] = @[];
                         mode = promptLineMode;
                         capabilities = PromptCapabilities();
                         size = none(PromptSize)): ScriptedSession =
  ## Creates a session that returns ``events`` and captures every write.
  ScriptedSession(events: events, selectedMode: mode,
    detectedCapabilities: capabilities, detectedSize: size)

method readEvent*(value: ScriptedSession;
                  timeoutMs = -1): PromptInputEvent =
  if value.closed:
    raise newException(PromptStateError, "cannot read from a closed session")
  if value.failRead:
    raise newException(PromptIOError, "injected read failure")
  if value.nextEvent >= value.events.len:
    return endInput()
  result = value.events[value.nextEvent]
  inc value.nextEvent

method write*(value: ScriptedSession; text: string) =
  if value.closed:
    raise newException(PromptStateError, "cannot write to a closed session")
  if value.failWrite:
    raise newException(PromptIOError, "injected write failure")
  value.output.add text

method flush*(value: ScriptedSession) =
  if value.closed:
    raise newException(PromptStateError, "cannot flush a closed session")
  inc value.flushCount
  if value.failFlush:
    raise newException(PromptIOError, "injected flush failure")

method mode*(value: ScriptedSession): PromptSessionMode =
  value.selectedMode

method capabilities*(value: ScriptedSession): PromptCapabilities =
  value.detectedCapabilities

method terminalSize*(value: ScriptedSession): Option[PromptSize] =
  value.detectedSize

method close*(value: ScriptedSession) =
  if value.closed:
    return
  value.closed = true
  inc value.closeCount
  if value.failClose:
    raise newException(PromptIOError, "injected close failure")
