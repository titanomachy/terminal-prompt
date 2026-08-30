## Unicode-aware state and operations shared by editable prompts.
##
## Cursor positions are terminal grapheme positions rather than UTF-8 byte
## offsets. This keeps movement and deletion aligned with the same grapheme
## and cell-width behavior used by TerminalStyle rendering.

import std/unicode

import terminal_style

import ./types

type LineEditor* = object
  ## Mutable, single-line text with a cursor between terminal graphemes.
  units: seq[string]
  cursor: int

proc validateText(value: string) =
  let invalidByte = value.validateUtf8
  if invalidByte >= 0:
    raise newException(ValueError,
      "line editor text is not valid UTF-8 at byte " & $invalidByte)

  var byteIndex = 0
  while byteIndex < value.len:
    let
      codepoint = int(value.runeAt(byteIndex))
      byteLength = value.runeLenAt(byteIndex)
    if codepoint < 0x20 or codepoint in 0x7f .. 0x9f:
      raise newException(ValueError,
        "line editor text cannot contain control characters")
    byteIndex += byteLength

proc terminalGraphemes(value: string): seq[string] =
  ## Groups runes according to TerminalStyle's display-cell behavior. A
  ## zero-width rune, joined emoji component, or regional-indicator pair stays
  ## attached to the preceding visible unit.
  validateText(value)
  var byteIndex = 0
  while byteIndex < value.len:
    let byteLength = value.runeLenAt(byteIndex)
    let runeText = value[byteIndex ..< byteIndex + byteLength]
    byteIndex += byteLength

    if result.len == 0:
      result.add runeText
      continue

    let
      previousWidth = result[^1].displayWidth
      runeWidth = runeText.displayWidth
      joinedWidth = (result[^1] & runeText).displayWidth
    if runeWidth == 0 or joinedWidth < previousWidth + runeWidth:
      result[^1].add runeText
    else:
      result.add runeText

proc value*(editor: LineEditor): string =
  ## Returns the current unmodified text.
  for unit in editor.units:
    result.add unit

proc len*(editor: LineEditor): int {.inline.} =
  ## Returns the number of editable terminal graphemes.
  editor.units.len

proc isEmpty*(editor: LineEditor): bool {.inline.} =
  ## Returns whether the editor contains no text.
  editor.units.len == 0

proc cursorPosition*(editor: LineEditor): int {.inline.} =
  ## Returns the cursor's zero-based terminal-grapheme position.
  editor.cursor

proc cursorColumn*(editor: LineEditor): int =
  ## Returns the terminal-cell width of the text before the cursor.
  for index in 0 ..< editor.cursor:
    result += editor.units[index].displayWidth

proc displayWidth*(editor: LineEditor): int =
  ## Returns the total terminal-cell width of the edited text.
  editor.value.displayWidth

proc beforeCursor*(editor: LineEditor): string =
  ## Returns the text strictly before the cursor.
  for index in 0 ..< editor.cursor:
    result.add editor.units[index]

proc afterCursor*(editor: LineEditor): string =
  ## Returns the text at and after the cursor.
  for index in editor.cursor ..< editor.units.len:
    result.add editor.units[index]

proc initLineEditor*(value = ""): LineEditor =
  ## Creates an editor with its cursor at the end of ``value``.
  result.units = terminalGraphemes(value)
  result.cursor = result.units.len

proc setValue*(editor: var LineEditor; value: string) =
  ## Replaces all text and moves the cursor to its end.
  editor.units = terminalGraphemes(value)
  editor.cursor = editor.units.len

proc setCursor*(editor: var LineEditor; position: int) =
  ## Moves the cursor to an exact terminal-grapheme boundary.
  if position < 0 or position > editor.units.len:
    raise newException(PromptStateError,
      "line editor cursor position is outside the text")
  editor.cursor = position

proc moveLeft*(editor: var LineEditor): bool =
  ## Moves one terminal grapheme left and reports whether it moved.
  if editor.cursor == 0:
    return false
  dec editor.cursor
  true

proc moveRight*(editor: var LineEditor): bool =
  ## Moves one terminal grapheme right and reports whether it moved.
  if editor.cursor == editor.units.len:
    return false
  inc editor.cursor
  true

proc moveFirst*(editor: var LineEditor): bool =
  ## Moves to the beginning and reports whether it moved.
  result = editor.cursor != 0
  editor.cursor = 0

proc moveLast*(editor: var LineEditor): bool =
  ## Moves to the end and reports whether it moved.
  result = editor.cursor != editor.units.len
  editor.cursor = editor.units.len

proc byteOffset(editor: LineEditor): int =
  for index in 0 ..< editor.cursor:
    result += editor.units[index].len

proc cursorAfterByte(units: openArray[string]; bytePosition: int): int =
  if bytePosition <= 0:
    return 0
  var consumed = 0
  for index, unit in units:
    consumed += unit.len
    if consumed >= bytePosition:
      return index + 1
  units.len

proc insert*(editor: var LineEditor; text: string): bool =
  ## Inserts valid, control-free single-line UTF-8 at the cursor.
  ##
  ## The complete value is regrouped after insertion so combining marks and
  ## joined emoji can merge correctly with neighboring terminal graphemes.
  if text.len == 0:
    return false
  validateText(text)

  let insertionByte = editor.byteOffset
  var updated = editor.value
  updated.insert(text, insertionByte)
  editor.units = terminalGraphemes(updated)
  editor.cursor = cursorAfterByte(editor.units, insertionByte + text.len)
  true

proc deleteBackward*(editor: var LineEditor): bool =
  ## Deletes the complete terminal grapheme before the cursor.
  if editor.cursor == 0:
    return false
  editor.units.delete(editor.cursor - 1)
  dec editor.cursor
  true

proc deleteForward*(editor: var LineEditor): bool =
  ## Deletes the complete terminal grapheme at the cursor.
  if editor.cursor == editor.units.len:
    return false
  editor.units.delete(editor.cursor)
  true
