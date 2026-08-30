import std/[options, unittest]

import terminal_screen as screen
import terminal_style

import terminal_prompt
import terminal_prompt/[io, keys, render, session, terminal_screen_adapter]

import ./support/scripted_session

suite "PromptResult contract":
  test "answered, cancelled, and EOF are distinct normal outcomes":
    let answer = answered("Ada")
    check answer.status == promptAnswered
    check answer.isAnswered
    check answer.value == "Ada"
    check answer.valueOr("fallback") == "Ada"

    let cancellation = cancelled[string]()
    check cancellation.status == promptCancelled
    check cancellation.isCancelled
    check cancellation.valueOr("fallback") == "fallback"
    expect PromptValueError:
      discard cancellation.value

    let eof = endOfInput[string]()
    check eof.status == promptEndOfInput
    check eof.isEndOfInput
    expect PromptValueError:
      discard eof.value

suite "Injectable contracts":
  test "scripted I/O does not access process-global streams":
    let scripted = newScriptedSession(@[
      keys.keyInput(keys.keyText, text = "x"),
      keys.keyInput(keys.keyEnter)
    ])
    let io = PromptIO(scripted)
    check io.readEvent().keyEvent.text == "x"
    io.write("captured")
    io.flush()
    check scripted.output == "captured"
    check scripted.flushCount == 1

  test "session cleanup runs after an exception":
    let scripted = newScriptedSession()
    var caught = false
    try:
      withPromptSession(PromptSession(scripted)):
        raise newException(ValueError, "injected failure")
    except ValueError:
      caught = true
    check caught
    check scripted.closeCount == 1

suite "Renderer and theme contract":
  test "plain mode emits no ANSI and preserves semantic text":
    let renderer = newSemanticRenderer()
    let rendered = renderer.render(frame(@[
      segment(roleQuestion, "Project?"),
      segment(rolePlain, " "),
      segment(roleHint, "(required)")
    ]), defaultPromptTheme(), ansi = false)
    check rendered == "Project? (required)"
    check '\e' notin rendered

  test "ANSI mode maps semantic roles to TerminalStyle":
    let renderer = newSemanticRenderer()
    let rendered = renderer.render(frame(@[
      segment(roleError, "invalid"),
      segment(rolePlain, ": "),
      segment(roleAnswer, "retry")
    ]), defaultPromptTheme(), ansi = true)
    check rendered.stripAnsi == "invalid: retry"
    check '\e' in rendered

suite "TerminalScreen adapter":
  test "key text, modifiers, and raw sequence are preserved":
    let mapped = toPromptEvent(screen.keyInput(screen.keyText,
      text = "é", modifiers = {screen.modifierShift, screen.modifierAlt,
        screen.modifierCtrl}, sequence = "\eé"))
    check mapped.kind == inputKey
    check mapped.keyEvent.key == keys.keyText
    check mapped.keyEvent.text == "é"
    check mapped.keyEvent.sequence == "\eé"
    check mapped.keyEvent.modifiers == {keys.modifierShift, keys.modifierAlt,
      keys.modifierCtrl}

  test "control, resize, timeout, and EOF events stay normalized":
    check toPromptEvent(screen.keyInput(screen.keyCtrlC)).keyEvent.key ==
      keys.keyCtrlC

    let resized = toPromptEvent(screen.resizeInput(screen.terminalSize(90, 30)))
    check resized.kind == inputResize
    check resized.size == PromptSize(columns: 90, rows: 30)
    check toPromptEvent(screen.timeoutInput()).kind == inputTimeout
    check toPromptEvent(screen.endOfInput()).kind == inputEndOfInput

suite "Public option contracts":
  test "options retain defaults, validators, labels, and typed choices":
    let validator: Validator[string] = proc(value: string): string =
      if value.len == 0: "required" else: ""
    var bindings = defaultPromptKeyBindings()
    bindings.submit = @[keyBinding(terminal_prompt.keyEnter),
      keyBinding(terminal_prompt.keyText, "s", {terminal_prompt.modifierCtrl})]
    let runtime = defaultRuntimeOptions(input = stdin, output = stderr,
      keyBindings = bindings)
    let textOptions = initTextPromptOptions("Name",
      defaultValue = some("Ada"), placeholder = "Your name",
      validator = validator, runtime = runtime)
    check textOptions.defaultValue.get == "Ada"
    check textOptions.validator("") == "required"
    check textOptions.runtime.output == stderr
    check textOptions.runtime.keyBindings.submit[1] ==
      keyBinding(terminal_prompt.keyText, "s", {terminal_prompt.modifierCtrl})

    let selectOptions = initSelectPromptOptions("Port", @[
      choice("HTTP", 80), choice("HTTPS", 443, hint = "recommended")
    ], initialIndex = some(1))
    check selectOptions.choices[1].value == 443
    check selectOptions.initialIndex.get == 1

  test "selection calls advertise their milestone status":
    expect PromptNotImplementedError:
      discard askSelect("Color", ["Red", "Blue"])
