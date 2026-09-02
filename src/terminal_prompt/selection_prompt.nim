## Shared single- and multiple-selection state machine.

import std/[options, parseutils, strutils]

import terminal_style

import ./[display, editor, input_engine, io, keys, render, session, types]

type
  SelectionPromptSpec* = object
    ## Behavior shared by single- and multiple-selection prompts.
    message*: string
    helpText*: string
    multiple*: bool
    wrapNavigation*: bool
    theme*: PromptTheme
    keyBindings*: PromptKeyBindings

proc firstEnabled[T](choices: openArray[PromptChoice[T]]): int =
  for index, item in choices:
    if not item.disabled:
      return index
  -1

proc lastEnabled[T](choices: openArray[PromptChoice[T]]): int =
  for index in countdown(choices.high, 0):
    if not choices[index].disabled:
      return index
  -1

proc moveFocus[T](choices: openArray[PromptChoice[T]]; current, direction: int;
                  wrapNavigation: bool): int =
  if choices.len == 0:
    return -1
  if current < 0:
    return if direction < 0: choices.lastEnabled else: choices.firstEnabled

  var candidate = current + direction
  while candidate >= 0 and candidate < choices.len:
    if not choices[candidate].disabled:
      return candidate
    candidate += direction

  if wrapNavigation:
    if direction < 0: choices.lastEnabled else: choices.firstEnabled
  else:
    current

proc adjustViewport(start: var int; focus, total, capacity: int) =
  if total <= capacity:
    start = 0
    return
  start = clamp(start, 0, total - capacity)
  if focus < start:
    start = focus
  elif focus >= start + capacity:
    start = focus - capacity + 1
  start = clamp(start, 0, total - capacity)

proc renderLine(renderer: PromptRenderer; segments: sink seq[PromptSegment];
                theme: PromptTheme; ansi: bool;
                columns: Option[int]): string =
  result = renderer.render(frame(segments), theme, ansi)
  if columns.isSome:
    result = result.truncateAnsi(max(1, columns.get()), suffix = "")

proc keyName(binding: PromptKeyBinding): string =
  if modifierCtrl in binding.modifiers:
    result.add "Ctrl+"
  if modifierAlt in binding.modifiers:
    result.add "Alt+"
  if modifierShift in binding.modifiers:
    result.add "Shift+"
  case binding.key
  of keyText:
    result.add binding.text
  of keySpace:
    result.add "Space"
  of keyEnter:
    result.add "Enter"
  of keyEscape:
    result.add "Esc"
  of keyTab:
    result.add "Tab"
  of keyBacktab:
    result.add "Backtab"
  of keyBackspace:
    result.add "Backspace"
  of keyDelete:
    result.add "Delete"
  of keyInsert:
    result.add "Insert"
  of keyHome:
    result.add "Home"
  of keyEnd:
    result.add "End"
  of keyArrowUp:
    result.add "Up"
  of keyArrowDown:
    result.add "Down"
  of keyArrowLeft:
    result.add "Left"
  of keyArrowRight:
    result.add "Right"
  of keyPageUp:
    result.add "PageUp"
  of keyPageDown:
    result.add "PageDown"
  of keyCtrlC:
    result.add "C"
  of keyCtrlD:
    result.add "D"
  of keyUnknown:
    result.add "Unknown"

proc actionHint(bindings: openArray[PromptKeyBinding]; action: string): string =
  if bindings.len > 0:
    result = bindings[0].keyName & " " & action

proc renderSelectionFrame[T](renderer: PromptRenderer;
                             choices: openArray[PromptChoice[T]];
                             selected: openArray[bool]; focus: int;
                             spec: SelectionPromptSpec;
                             mode: PromptSessionMode;
                             size: Option[PromptSize];
                             viewportStart: var int; error: string;
                             lineEditor: LineEditor): string =
  let
    ansi = mode == promptInteractiveMode
    columns = if size.isSome: some(size.get().columns) else: none(int)
  var lines: seq[string]

  if error.len > 0:
    lines.add renderer.renderLine(@[
      segment(roleError, "! " & error)
    ], spec.theme, ansi, columns)

  var heading = @[segment(roleQuestion, "? " & spec.message)]
  if spec.helpText.len > 0:
    heading.add segment(roleHint, " (" & spec.helpText & ")")

  var first = 0
  var afterLast = choices.len
  if mode == promptInteractiveMode and size.isSome:
    let capacity = max(1, size.get().rows - 2)
    viewportStart.adjustViewport(focus, choices.len, capacity)
    first = viewportStart
    afterLast = min(choices.len, first + capacity)
    if choices.len > capacity:
      let position = if focus >= 0: focus + 1 else: 0
      heading.add segment(roleHint,
        " [" & $position & "/" & $choices.len & "]")
  else:
    viewportStart = 0
  lines.add renderer.renderLine(heading, spec.theme, ansi, columns)

  for index in first ..< afterLast:
    let item = choices[index]
    var choiceLine: seq[PromptSegment]
    let pointer = if index == focus: "> " else: "  "
    if spec.multiple:
      let marker = if item.disabled: "[-] "
        elif selected[index]: "[x] "
        else: "[ ] "
      choiceLine.add segment(
        if index == focus: roleSelection else: rolePlain,
        pointer & marker & $(index + 1) & ". ")
    else:
      choiceLine.add segment(
        if index == focus: roleSelection else: rolePlain,
        pointer & $(index + 1) & ". ")
    choiceLine.add segment(
      if item.disabled: roleHint
      elif index == focus: roleSelection
      else: rolePlain,
      item.label)
    if item.hint.len > 0:
      choiceLine.add segment(roleHint, " - " & item.hint)
    if item.disabled:
      choiceLine.add segment(roleHint, " (disabled)")
    lines.add renderer.renderLine(choiceLine, spec.theme, ansi, columns)

  var instructions: seq[PromptSegment]
  if mode == promptInteractiveMode:
    var actions: seq[string]
    if spec.keyBindings.moveUp.len > 0 and spec.keyBindings.moveDown.len > 0:
      actions.add spec.keyBindings.moveUp[0].keyName & "/" &
        spec.keyBindings.moveDown[0].keyName & " navigate"
    if spec.multiple:
      for item in [
        spec.keyBindings.toggle.actionHint("toggle"),
        spec.keyBindings.selectAll.actionHint("all"),
        spec.keyBindings.clearSelection.actionHint("clear")
      ]:
        if item.len > 0:
          actions.add item
    let submit = spec.keyBindings.submit.actionHint(
      if spec.multiple: "submit" else: "select")
    if submit.len > 0:
      actions.add submit
    instructions.add segment(roleHint, actions.join(" | "))
  else:
    let text = if spec.multiple:
        "Enter choice numbers separated by commas (blank keeps defaults): "
      else:
        "Enter a choice number (blank uses the default): "
    instructions.add segment(roleHint, text)
    if not lineEditor.isEmpty:
      instructions.add segment(roleAnswer, lineEditor.value)
  lines.add renderer.renderLine(instructions, spec.theme, ansi, columns)
  lines.join("\n")

proc selectedLabels[T](choices: openArray[PromptChoice[T]];
                       selected: openArray[bool]): string =
  var labels: seq[string]
  for index, item in choices:
    if selected[index]:
      labels.add item.label
  if labels.len == 0: "(none)" else: labels.join(", ")

proc renderFinal[T](renderer: PromptRenderer;
                    choices: openArray[PromptChoice[T]];
                    selected: openArray[bool]; spec: SelectionPromptSpec;
                    ansi: bool): string =
  renderer.render(frame(@[
    segment(roleQuestion, "? " & spec.message & ": "),
    segment(roleAnswer, choices.selectedLabels(selected))
  ]), spec.theme, ansi)

proc insertLineKey(lineEditor: var LineEditor; key: PromptKeyEvent): bool =
  if (modifierCtrl in key.modifiers) xor
      (modifierAlt in key.modifiers):
    return false
  case key.key
  of keyText, keySpace:
    if key.text.len == 0:
      return false
    try:
      lineEditor.insert(key.text)
    except ValueError:
      false
  else:
    false

proc parseOneIndex(value: string; count: int): tuple[valid: bool, index: int] =
  let candidate = value.strip
  var parsed = 0
  if candidate.len == 0 or parseInt(candidate, parsed) != candidate.len or
      parsed < 1 or parsed > count:
    return (false, -1)
  (true, parsed - 1)

proc parseManyIndices[T](value: string; choices: openArray[PromptChoice[T]];
                         current: openArray[bool]):
    tuple[valid: bool, selected: seq[bool], error: string] =
  result.selected = @current
  let candidate = value.strip
  if candidate.len == 0:
    result.valid = true
    return

  result.selected = newSeq[bool](choices.len)
  var foundIndex = false
  for token in candidate.split({',', ' ', '\t'}):
    if token.len == 0:
      continue
    foundIndex = true
    let parsed = token.parseOneIndex(choices.len)
    if not parsed.valid:
      result.error = "Enter valid choice numbers between 1 and " &
        $choices.len & "."
      return
    if choices[parsed.index].disabled:
      result.error = "Choice " & $(parsed.index + 1) & " is disabled."
      return
    result.selected[parsed.index] = true
  if not foundIndex:
    result.error = "Enter at least one choice number."
    return
  result.valid = true

proc runSelectionPrompt*[T](session: PromptSession;
                            choices: seq[PromptChoice[T]];
                            initialFocus: int;
                            initiallySelected: seq[bool];
                            spec: SelectionPromptSpec): PromptResult[seq[int]] =
  ## Runs a selection prompt and returns selected choice indices in list order.
  if session.isNil:
    raise newException(PromptStateError, "prompt session cannot be nil")
  if initiallySelected.len != choices.len:
    session.close()
    raise newException(PromptStateError,
      "selection state must have one entry per choice")

  try:
    let
      promptMode = session.mode
      ansi = promptMode == promptInteractiveMode
      renderer = newSemanticRenderer()
      display = newPromptDisplay(PromptIO(session), promptMode,
        session.terminalSize)
      engine = newPromptInputEngine(PromptIO(session), spec.keyBindings)
    try:
      var
        selected = initiallySelected
        focus = initialFocus
        size = session.terminalSize
        viewportStart = 0
        validationError = ""
        lineEditor = initLineEditor()
      display.redraw(renderer.renderSelectionFrame(choices, selected, focus,
        spec, promptMode, size, viewportStart, validationError, lineEditor))

      while true:
        let event = engine.readInput()
        var
          redraw = false
          lineRedraw = false
        case event.kind
        of engineAction:
          case event.action
          of actionCancel:
            return cancelled[seq[int]]()
          of actionSubmit:
            if promptMode == promptLineMode and not spec.multiple:
              if not lineEditor.isEmpty:
                let parsed = lineEditor.value.parseOneIndex(choices.len)
                if not parsed.valid:
                  validationError = "Enter a valid choice number between 1 and " &
                    $choices.len & "."
                  lineEditor.setValue("")
                  lineRedraw = true
                elif choices[parsed.index].disabled:
                  validationError = "Choice " & $(parsed.index + 1) &
                    " is disabled."
                  lineEditor.setValue("")
                  lineRedraw = true
                else:
                  focus = parsed.index
              if lineRedraw:
                discard
              elif focus < 0:
                validationError = "No enabled choice is available."
                lineRedraw = true
              else:
                selected = newSeq[bool](choices.len)
                selected[focus] = true
            elif promptMode == promptLineMode:
              let parsed = parseManyIndices(lineEditor.value, choices, selected)
              if not parsed.valid:
                validationError = parsed.error
                lineEditor.setValue("")
                lineRedraw = true
              else:
                selected = parsed.selected
            elif not spec.multiple:
              if focus >= 0:
                selected = newSeq[bool](choices.len)
                selected[focus] = true

            if not lineRedraw:
              var indices: seq[int]
              for index, isSelected in selected:
                if isSelected:
                  indices.add index
              display.finish(renderer.renderFinal(choices, selected, spec,
                ansi))
              return answered(indices)
          of actionMoveUp:
            let moved = choices.moveFocus(focus, -1, spec.wrapNavigation)
            redraw = moved != focus
            focus = moved
          of actionMoveDown:
            let moved = choices.moveFocus(focus, 1, spec.wrapNavigation)
            redraw = moved != focus
            focus = moved
          of actionMoveFirst:
            let moved = choices.firstEnabled
            redraw = moved != focus
            focus = moved
          of actionMoveLast:
            let moved = choices.lastEnabled
            redraw = moved != focus
            focus = moved
          of actionToggle:
            if promptMode == promptLineMode:
              redraw = lineEditor.insertLineKey(event.actionKey)
            elif spec.multiple and focus >= 0:
              selected[focus] = not selected[focus]
              redraw = true
          of actionSelectAll:
            if spec.multiple:
              for index, item in choices:
                selected[index] = not item.disabled
              redraw = true
            elif promptMode == promptLineMode:
              redraw = lineEditor.insertLineKey(event.actionKey)
          of actionClearSelection:
            if spec.multiple:
              selected = newSeq[bool](choices.len)
              redraw = true
            elif promptMode == promptLineMode:
              redraw = lineEditor.insertLineKey(event.actionKey)
          of actionDeleteBackward:
            if promptMode == promptLineMode:
              redraw = lineEditor.deleteBackward()
          of actionDeleteForward:
            if promptMode == promptLineMode:
              redraw = lineEditor.deleteForward()
          of actionMoveLeft:
            if promptMode == promptLineMode:
              redraw = lineEditor.moveLeft()
          of actionMoveRight:
            if promptMode == promptLineMode:
              redraw = lineEditor.moveRight()
        of engineKey:
          if promptMode == promptLineMode:
            if event.key.key == keyCtrlD and lineEditor.isEmpty:
              return endOfInput[seq[int]]()
            redraw = lineEditor.insertLineKey(event.key)
        of engineResize:
          size = some(event.size)
          display.updateSize(event.size)
          redraw = true
        of engineEndOfInput:
          return endOfInput[seq[int]]()
        of engineTimeout:
          discard

        if redraw and promptMode == promptInteractiveMode:
          display.redraw(renderer.renderSelectionFrame(choices, selected,
            focus, spec, promptMode, size, viewportStart, validationError,
            lineEditor))
        elif lineRedraw:
          display.redraw(renderer.renderSelectionFrame(choices, selected,
            focus, spec, promptMode, size, viewportStart, validationError,
            lineEditor))
    finally:
      display.close()
  finally:
    session.close()
