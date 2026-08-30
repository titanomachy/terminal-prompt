## Cursor-safe prompt redraw and cleanup over injected I/O.

import std/[options, strutils]

import terminal_style

import ./[io, keys, session, types]

const
  EraseLine = "\e[2K"
  CursorUp = "\e[1A"

type PromptDisplay* = ref object
  ## Owns one transient prompt frame and restores a clean output position.
  io: PromptIO
  sessionMode: PromptSessionMode
  columns: Option[int]
  renderedText: string
  active: bool
  closed: bool

proc lineRows(value: string; columns: Option[int]): int =
  let lines = value.split('\n')
  for line in lines:
    if columns.isSome:
      let width = line.displayWidth
      result += max(1, (width + columns.get() - 1) div columns.get())
    else:
      inc result

proc eraseFrameCode*(value: string; columns = none(int)): string =
  ## Builds controls that erase ``value`` from its final row back to its first.
  let rows = lineRows(value, columns)
  result = "\r" & EraseLine
  for _ in 1 ..< rows:
    result.add CursorUp & "\r" & EraseLine

proc newPromptDisplay*(io: PromptIO; mode: PromptSessionMode;
                       size = none(PromptSize)): PromptDisplay =
  ## Creates a display that redraws only in interactive mode.
  if io.isNil:
    raise newException(PromptStateError, "prompt display output cannot be nil")
  result = PromptDisplay(io: io, sessionMode: mode)
  if size.isSome:
    result.columns = some(size.get().columns)

proc updateSize*(display: PromptDisplay; size: PromptSize) =
  ## Updates wrapping calculations after a resize event.
  if display.isNil or display.closed:
    raise newException(PromptStateError, "cannot resize a closed prompt display")
  display.columns = some(size.columns)

proc redraw*(display: PromptDisplay; value: string) =
  ## Draws a transient frame, erasing the prior frame when ANSI is safe.
  if display.isNil or display.closed:
    raise newException(PromptStateError, "cannot redraw a closed prompt display")
  if display.active:
    if display.sessionMode == promptInteractiveMode:
      display.io.write(eraseFrameCode(display.renderedText, display.columns))
    else:
      display.io.write("\n")
  display.io.write(value)
  display.renderedText = value
  display.active = true
  display.io.flush()

proc clear*(display: PromptDisplay) =
  ## Clears the active interactive frame; line-mode history is preserved.
  if display.isNil or not display.active:
    return
  display.active = false
  if display.sessionMode == promptInteractiveMode:
    display.io.write(eraseFrameCode(display.renderedText, display.columns))
    display.io.flush()

proc finish*(display: PromptDisplay; value = "") =
  ## Replaces the transient frame with an optional permanent output line.
  if display.isNil or display.closed:
    raise newException(PromptStateError, "cannot finish a closed prompt display")
  if display.active:
    if display.sessionMode == promptInteractiveMode:
      display.clear()
    else:
      display.io.write("\n")
      display.active = false
  if value.len > 0:
    display.io.write(value)
    display.io.write("\n")
  display.io.flush()
  display.closed = true

proc close*(display: PromptDisplay) =
  ## Restores the output position; repeated calls are safe.
  if display.isNil or display.closed:
    return
  display.closed = true
  if display.active:
    display.active = false
    if display.sessionMode == promptInteractiveMode:
      display.io.write(eraseFrameCode(display.renderedText, display.columns))
    else:
      display.io.write("\n")
    display.io.flush()

template withPromptDisplay*(display: PromptDisplay; body: untyped): untyped =
  ## Runs ``body`` and restores display output on return or exception.
  try:
    body
  finally:
    display.close()
