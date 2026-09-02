## Shared editable-line state machine for text-like prompts.

import std/[options, strutils]

import terminal_style

import ./[display, editor, input_engine, io, keys, render, session, types]

type
  LineSubmission* = object
    ## Decision returned when an editable prompt is submitted.
    accepted*: bool
    answer*: string
    error*: string

  LineSubmitter* = proc(value: string): LineSubmission {.closure.}
    ## Validates and optionally transforms one submitted line.

  LinePromptSpec* = object
    ## Rendering and security behavior for one editable prompt.
    message*: string
    hint*: string
    helpText*: string
    placeholder*: string
    mask*: string
    secret*: bool
    theme*: PromptTheme
    keyBindings*: PromptKeyBindings

proc acceptLine*(answer: sink string): LineSubmission =
  ## Accepts a submitted line.
  LineSubmission(accepted: true, answer: answer)

proc retryLine*(error: sink string): LineSubmission =
  ## Rejects a submitted line with a user-facing error.
  LineSubmission(error: error)

proc validateSingleLine*(value, optionName: string) =
  ## Raises a configuration error unless ``value`` is safe single-line text.
  try:
    discard initLineEditor(value)
  except ValueError as error:
    raise newException(PromptConfigurationError,
      optionName & " must be valid, control-free, single-line UTF-8", error)

proc visibleValue(editor: LineEditor; spec: LinePromptSpec): string =
  if spec.secret:
    spec.mask.repeat(editor.len)
  else:
    editor.value

proc tailWidth(editor: LineEditor; spec: LinePromptSpec): int =
  if spec.secret:
    spec.mask.displayWidth * (editor.len - editor.cursorPosition)
  else:
    editor.afterCursor.displayWidth

proc renderFrame(renderer: PromptRenderer; editor: LineEditor;
                 spec: LinePromptSpec; error: string; ansi: bool;
                 finalAnswer = none(string)): string =
  var segments: seq[PromptSegment]
  if error.len > 0:
    segments.add segment(roleError, "! " & error)
    segments.add segment(rolePlain, "\n")

  segments.add segment(roleQuestion, "? " & spec.message)
  if spec.hint.len > 0:
    segments.add segment(roleHint, " " & spec.hint)
  if spec.helpText.len > 0:
    segments.add segment(roleHint, " (" & spec.helpText & ")")
  segments.add segment(rolePlain, ": ")

  var cursorBack = 0
  if finalAnswer.isSome:
    let answer = finalAnswer.get()
    if spec.secret:
      segments.add segment(roleAnswer,
        spec.mask.repeat(initLineEditor(answer).len))
    else:
      segments.add segment(roleAnswer, answer)
  else:
    let visible = editor.visibleValue(spec)
    if visible.len > 0:
      segments.add segment(roleAnswer, visible)
      cursorBack = editor.tailWidth(spec)
    elif spec.placeholder.len > 0:
      segments.add segment(rolePlaceholder, spec.placeholder)
      cursorBack = spec.placeholder.displayWidth

  if ansi and cursorBack > 0:
    segments.add segment(rolePlain, "\e[" & $cursorBack & "D")
  renderer.render(frame(segments), spec.theme, ansi)

proc insertKey(editor: var LineEditor; key: PromptKeyEvent): bool =
  # Native Windows input can represent AltGr text as Ctrl+Alt. Action bindings
  # have already been resolved, so an otherwise unbound printable chord should
  # remain insertable while lone Ctrl/Alt command chords stay ignored.
  if (modifierCtrl in key.modifiers) xor
      (modifierAlt in key.modifiers):
    return false
  case key.key
  of keyText, keySpace:
    if key.text.len == 0:
      return false
    try:
      editor.insert(key.text)
    except ValueError:
      false
  else:
    false

proc runLinePrompt*(session: PromptSession; spec: LinePromptSpec;
                    submitter: LineSubmitter): PromptResult[string] =
  ## Runs one editable prompt and owns ``session`` until it is closed.
  if session.isNil:
    raise newException(PromptStateError, "prompt session cannot be nil")
  if submitter.isNil:
    raise newException(PromptStateError, "line submitter cannot be nil")

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
        editor = initLineEditor()
        validationError = ""
      display.redraw(renderer.renderFrame(editor, spec, validationError, ansi))

      while true:
        let event = engine.readInput()
        var
          redraw = false
          lineRedraw = false
        case event.kind
        of engineAction:
          case event.action
          of actionCancel:
            return cancelled[string]()
          of actionSubmit:
            let decision = submitter(editor.value)
            if decision.accepted:
              display.finish(renderer.renderFrame(editor, spec, "",
                ansi = ansi,
                finalAnswer = some(decision.answer)))
              return answered(decision.answer, sensitive = spec.secret)
            validationError = decision.error
            if promptMode == promptLineMode:
              editor.setValue("")
            redraw = true
            lineRedraw = true
          of actionMoveLeft:
            redraw = editor.moveLeft()
          of actionMoveRight:
            redraw = editor.moveRight()
          of actionMoveFirst:
            redraw = editor.moveFirst()
          of actionMoveLast:
            redraw = editor.moveLast()
          of actionDeleteBackward:
            redraw = editor.deleteBackward()
          of actionDeleteForward:
            redraw = editor.deleteForward()
          of actionToggle:
            redraw = editor.insertKey(event.actionKey)
          of actionSelectAll, actionClearSelection:
            redraw = editor.insertKey(event.actionKey)
          of actionMoveUp, actionMoveDown:
            discard
        of engineKey:
          if event.key.key == keyCtrlD:
            if editor.isEmpty:
              return endOfInput[string]()
            redraw = editor.deleteForward()
          else:
            redraw = editor.insertKey(event.key)
        of engineResize:
          display.updateSize(event.size)
          redraw = true
        of engineEndOfInput:
          return endOfInput[string]()
        of engineTimeout:
          discard

        if redraw and promptMode == promptInteractiveMode:
          display.redraw(renderer.renderFrame(editor, spec,
            validationError, ansi))
        elif lineRedraw:
          display.redraw(renderer.renderFrame(editor, spec,
            validationError, ansi = false))
    finally:
      display.close()
  finally:
    session.close()
