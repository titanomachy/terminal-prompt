import std/[options, os, strutils, tempfiles, unittest]

import terminal_style

import terminal_prompt
import terminal_prompt/[confirm_prompt, keys, password_prompt, session,
  text_prompt, types]

import ./support/scripted_session

proc text(value: string): PromptInputEvent =
  keyInput(keyText, text = value, sequence = value)

proc enter(): PromptInputEvent =
  keyInput(keyEnter)

proc cancel(): PromptInputEvent =
  keyInput(keyEscape)

suite "text prompt":
  test "interactive editing submits Unicode-aware text and closes cleanly":
    let scripted = newScriptedSession(@[
      text("a"), text("c"), keyInput(keyArrowLeft), text("界"), enter()
    ], mode = promptInteractiveMode)
    let response = runTextPrompt(PromptSession(scripted),
      initTextPromptOptions("Name"))
    check response.isAnswered
    check response.value == "a界c"
    check scripted.output.stripAnsi.contains("a界c")
    check scripted.closeCount == 1

  test "empty submission uses a default while a placeholder is only visual":
    let withDefault = newScriptedSession(@[enter()])
    let defaultResponse = runTextPrompt(PromptSession(withDefault),
      initTextPromptOptions("Package", defaultValue = some("terminal-app"),
        placeholder = "ignored"))
    check defaultResponse.value == "terminal-app"
    check "terminal-app" in withDefault.output

    let withPlaceholder = newScriptedSession(@[enter()])
    let placeholderResponse = runTextPrompt(PromptSession(withPlaceholder),
      initTextPromptOptions("Alias", placeholder = "optional"))
    check placeholderResponse.value == ""
    check "optional" in withPlaceholder.output

  test "line mode renders validation errors and starts a fresh retry":
    let validator: Validator[string] = proc(value: string): string =
      if value.len < 2: "Use at least two characters" else: ""
    let scripted = newScriptedSession(@[
      text("x"), enter(), text("o"), text("k"), enter()
    ])
    let response = runTextPrompt(PromptSession(scripted),
      initTextPromptOptions("Code", validator = validator))
    check response.value == "ok"
    check scripted.output.contains("Use at least two characters")
    check '\e' notin scripted.output

  test "cancel and EOF remain distinct and close the session":
    let cancelledSession = newScriptedSession(@[text("ignored"), cancel()])
    check runTextPrompt(PromptSession(cancelledSession),
      initTextPromptOptions("Name")).isCancelled
    check cancelledSession.closeCount == 1

    let eofSession = newScriptedSession(@[text("unfinished"), endInput()])
    check runTextPrompt(PromptSession(eofSession),
      initTextPromptOptions("Name")).isEndOfInput
    check eofSession.closeCount == 1

  test "Ctrl+D is EOF only for an empty editor":
    let emptySession = newScriptedSession(@[keyInput(keyCtrlD)])
    check runTextPrompt(PromptSession(emptySession),
      initTextPromptOptions("Name")).isEndOfInput

    let editedSession = newScriptedSession(@[
      text("a"), text("b"), keyInput(keyArrowLeft), keyInput(keyCtrlD), enter()
    ])
    check runTextPrompt(PromptSession(editedSession),
      initTextPromptOptions("Name")).value == "a"

suite "password prompt":
  test "interactive output contains masks but never the answer":
    let secret = "s界cret"
    var events: seq[PromptInputEvent]
    for runeText in ["s", "界", "c", "r", "e", "t"]:
      events.add text(runeText)
    events.add enter()
    let scripted = newScriptedSession(events, mode = promptInteractiveMode)
    let response = runPasswordPrompt(PromptSession(scripted),
      initPasswordPromptOptions("Token", mask = "•"))
    check response.value == secret
    check secret notin scripted.output
    check secret notin $response
    check "[redacted]" in $response
    check scripted.output.stripAnsi.contains("••••••")

  test "validation retries redact secrets from user-facing errors":
    let validator: Validator[string] = proc(value: string): string =
      if value == "hunter2": value & " is rejected" else: ""
    let scripted = newScriptedSession(@[
      text("hunter2"), enter(), text("safer"), enter()
    ])
    let response = runPasswordPrompt(PromptSession(scripted),
      initPasswordPromptOptions("Password", validator = validator))
    check response.value == "safer"
    check "hunter2" notin scripted.output
    check "safer" notin scripted.output
    check "[redacted] is rejected" in scripted.output
    check scripted.closeCount == 1

  test "validator exceptions cannot expose the submitted password":
    let validator: Validator[string] = proc(value: string): string =
      raise newException(ValueError, "invalid password: " & value)
    let scripted = newScriptedSession(@[text("top-secret"), enter()])
    var message = ""
    try:
      discard runPasswordPrompt(PromptSession(scripted),
        initPasswordPromptOptions("Password", validator = validator))
    except PromptError as error:
      message = error.msg
    check message == "password validator failed without exposing its input"
    check "top-secret" notin message
    check "top-secret" notin scripted.output
    check scripted.closeCount == 1

  test "empty masks provide no-feedback entry without echoing input":
    let scripted = newScriptedSession(@[text("invisible"), enter()],
      mode = promptInteractiveMode)
    check runPasswordPrompt(PromptSession(scripted),
      initPasswordPromptOptions("Password", mask = "")).value == "invisible"
    check "invisible" notin scripted.output

  test "cancellation and EOF never produce or render partial secrets":
    let cancelledSession = newScriptedSession(@[
      text("partial-secret"), cancel()
    ], mode = promptInteractiveMode)
    let cancelledResponse = runPasswordPrompt(PromptSession(cancelledSession),
      initPasswordPromptOptions("Password"))
    check cancelledResponse.isCancelled
    check "partial-secret" notin cancelledSession.output

    let eofSession = newScriptedSession(@[text("unfinished"), endInput()])
    let eofResponse = runPasswordPrompt(PromptSession(eofSession),
      initPasswordPromptOptions("Password"))
    check eofResponse.isEndOfInput
    check "unfinished" notin eofSession.output

suite "confirmation prompt":
  test "Enter selects the configured boolean default":
    let yesDefault = newScriptedSession(@[enter()])
    check runConfirmPrompt(PromptSession(yesDefault),
      initConfirmPromptOptions("Continue", defaultValue = true)).value
    check "default: Yes" in yesDefault.output

    let noDefault = newScriptedSession(@[enter()])
    check not runConfirmPrompt(PromptSession(noDefault),
      initConfirmPromptOptions("Continue", defaultValue = false)).value
    check "default: No" in noDefault.output

  test "custom labels accept full labels and unambiguous initials":
    let shortSession = newScriptedSession(@[text("o"), enter()])
    check runConfirmPrompt(PromptSession(shortSession),
      initConfirmPromptOptions("Continuer", yesLabel = "Oui",
        noLabel = "Non")).value
    check "[Oui/Non, default: Non]" in shortSession.output

    let fullSession = newScriptedSession(@[text("NOPE"), enter()])
    check not runConfirmPrompt(PromptSession(fullSession),
      initConfirmPromptOptions("Proceed", yesLabel = "Yep",
        noLabel = "Nope")).value

  test "interactive confirmation redraws after resize and editing":
    let scripted = newScriptedSession(@[
      resizeInput(60, 20), text("n"), enter()
    ], mode = promptInteractiveMode, size = some(PromptSize(
      columns: 40, rows: 20)))
    let response = runConfirmPrompt(PromptSession(scripted),
      initConfirmPromptOptions("Continue"))
    check not response.value
    check scripted.output.stripAnsi.contains("No")
    check scripted.closeCount == 1

  test "invalid line-mode input renders an error and retries":
    let scripted = newScriptedSession(@[
      text("maybe"), enter(), text("y"), enter()
    ])
    let response = runConfirmPrompt(PromptSession(scripted),
      initConfirmPromptOptions("Continue"))
    check response.value
    check "Enter Yes or No." in scripted.output

  test "ambiguous initials require a complete label":
    let scripted = newScriptedSession(@[
      text("y"), enter(), text("yeah"), enter()
    ])
    let response = runConfirmPrompt(PromptSession(scripted),
      initConfirmPromptOptions("Continue", yesLabel = "Yes",
        noLabel = "Yeah"))
    check not response.value
    check "Enter Yes or Yeah." in scripted.output

  test "cancel and EOF preserve their result statuses":
    let cancelledSession = newScriptedSession(@[cancel()])
    check runConfirmPrompt(PromptSession(cancelledSession),
      initConfirmPromptOptions("Continue")).isCancelled
    let eofSession = newScriptedSession(@[endInput()])
    check runConfirmPrompt(PromptSession(eofSession),
      initConfirmPromptOptions("Continue")).isEndOfInput

suite "configuration and public line-mode integration":
  test "invalid masks and confirmation labels fail before interaction":
    let maskSession = newScriptedSession()
    expect PromptConfigurationError:
      discard runPasswordPrompt(PromptSession(maskSession),
        initPasswordPromptOptions("Password", mask = "xx"))
    check maskSession.closeCount == 1

    let labelSession = newScriptedSession()
    expect PromptConfigurationError:
      discard runConfirmPrompt(PromptSession(labelSession),
        initConfirmPromptOptions("Continue", yesLabel = "same",
          noLabel = "SAME"))
    check labelSession.closeCount == 1

  test "public APIs consume redirected lines through TerminalScreen":
    let inputTemp = createTempFile("terminal_prompt_m2_input_", ".txt")
    let outputTemp = createTempFile("terminal_prompt_m2_output_", ".txt")
    defer:
      inputTemp.cfile.close()
      outputTemp.cfile.close()
      removeFile(inputTemp.path)
      removeFile(outputTemp.path)
    inputTemp.cfile.write("Ada\nsecret-value\ny\n")
    inputTemp.cfile.flushFile()
    inputTemp.cfile.setFilePos(0)
    let runtime = defaultRuntimeOptions(inputTemp.cfile, outputTemp.cfile)

    check askText(initTextPromptOptions("Name", runtime = runtime)).value ==
      "Ada"
    check askPassword(initPasswordPromptOptions("Password",
      runtime = runtime)).value == "secret-value"
    check askConfirm(initConfirmPromptOptions("Continue",
      runtime = runtime)).value

    outputTemp.cfile.flushFile()
    let output = readFile(outputTemp.path)
    check "Ada" in output
    check "secret-value" notin output
    check '\e' notin output
