## Backend-neutral input events consumed by prompt state machines.

import ./types

export types

type
  PromptKeyEvent* = object
    key*: PromptKey
    text*: string
    sequence*: string
    modifiers*: set[PromptModifier]

  PromptSize* = object
    columns*: int
    rows*: int

  PromptInputEventKind* = enum
    inputKey
    inputResize
    inputEndOfInput
    inputTimeout

  PromptInputEvent* = object
    case kind*: PromptInputEventKind
    of inputKey:
      keyEvent*: PromptKeyEvent
    of inputResize:
      size*: PromptSize
    of inputEndOfInput, inputTimeout:
      discard

proc keyInput*(key: PromptKey; text = "";
               modifiers: set[PromptModifier] = {};
               sequence = ""): PromptInputEvent =
  ## Constructs a backend-neutral key event.
  PromptInputEvent(kind: inputKey,
    keyEvent: PromptKeyEvent(key: key, text: text, sequence: sequence,
      modifiers: modifiers))

proc resizeInput*(columns, rows: int): PromptInputEvent =
  ## Constructs a resize event with validated positive dimensions.
  if columns <= 0 or rows <= 0:
    raise newException(ValueError, "prompt dimensions must be positive")
  PromptInputEvent(kind: inputResize,
    size: PromptSize(columns: columns, rows: rows))

proc endInput*(): PromptInputEvent =
  ## Constructs an end-of-input event.
  PromptInputEvent(kind: inputEndOfInput)

proc timeoutInput*(): PromptInputEvent =
  ## Constructs a timeout event.
  PromptInputEvent(kind: inputTimeout)
