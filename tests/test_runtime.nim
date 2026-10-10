## Tests session selection, input dispatch, display cleanup, and backend adaptation.

import std/[options, os, strutils, tempfiles, unittest]

import terminal_screen as screen

import terminal_prompt
import terminal_prompt/[display, input_engine, io, keys, password_prompt, session,
  terminal_screen_adapter, types]

import ./support/scripted_session

proc failTerminalSetup(input, output: File;
                       options: screen.SessionOptions): screen.TerminalSession =
  raise newException(screen.TerminalStateError, "injected setup failure")

suite "session mode selection":
  test "fully capable streams use interactive mode":
    let capabilities = PromptCapabilities(inputIsTerminal: true,
      outputIsTerminal: true, supportsAnsi: true, supportsRawMode: true,
      supportsResizeEvents: true)
    check capabilities.selectSessionMode() == promptInteractiveMode

  test "missing raw, ANSI, input TTY, or output TTY selects line mode":
    let complete = PromptCapabilities(inputIsTerminal: true,
      outputIsTerminal: true, supportsAnsi: true, supportsRawMode: true)
    var options = defaultPromptSessionOptions()
    options.rawMode = false
    check complete.selectSessionMode(options) == promptLineMode
    check PromptCapabilities(outputIsTerminal: true, supportsAnsi: true,
      supportsRawMode: true).selectSessionMode() == promptLineMode
    check PromptCapabilities(inputIsTerminal: true, supportsAnsi: true,
      supportsRawMode: true).selectSessionMode() == promptLineMode
    check PromptCapabilities(inputIsTerminal: true, outputIsTerminal: true,
      supportsRawMode: true).selectSessionMode() == promptLineMode
    check PromptCapabilities(inputIsTerminal: true, outputIsTerminal: true,
      supportsAnsi: true).selectSessionMode() == promptLineMode

  test "redirected streams open in plain line mode by default":
    let inputTemp = createTempFile("terminal_prompt_input_", ".txt")
    let outputTemp = createTempFile("terminal_prompt_output_", ".txt")
    defer:
      inputTemp.cfile.close()
      outputTemp.cfile.close()
      removeFile(inputTemp.path)
      removeFile(outputTemp.path)
    inputTemp.cfile.write("x\n")
    inputTemp.cfile.flushFile()
    inputTemp.cfile.setFilePos(0)

    let promptSession = openTerminalScreenSession(
      inputTemp.cfile, outputTemp.cfile)
    check promptSession.mode == promptLineMode
    check not promptSession.capabilities.supportsAnsi
    check promptSession.readEvent().keyEvent.text == "x"
    check promptSession.readEvent().keyEvent.key == types.keyEnter
    check promptSession.readEvent().kind == keys.inputEndOfInput
    promptSession.write("captured")
    promptSession.flush()
    promptSession.close()
    promptSession.close()
    check readFile(outputTemp.path) == "captured"

  test "strict terminal requirements still reject redirected streams":
    let inputTemp = createTempFile("terminal_prompt_input_", ".txt")
    let outputTemp = createTempFile("terminal_prompt_output_", ".txt")
    defer:
      inputTemp.cfile.close()
      outputTemp.cfile.close()
      removeFile(inputTemp.path)
      removeFile(outputTemp.path)
    var options = defaultPromptSessionOptions()
    options.requireTerminal = true
    expect PromptIOError:
      discard openTerminalScreenSession(
        inputTemp.cfile, outputTemp.cfile, options)

  test "interactive setup failures fall back unless strict mode is requested":
    let capabilities = PromptCapabilities(inputIsTerminal: true,
      outputIsTerminal: true, supportsAnsi: true, supportsRawMode: true,
      supportsResizeEvents: true)
    let defaults = defaultPromptSessionOptions()
    let fallback = openTerminalScreenSessionWithCapabilities(
      stdin, stdout, defaults, capabilities, failTerminalSetup)
    check fallback.mode == promptLineMode
    check not fallback.capabilities.supportsAnsi
    check not fallback.capabilities.supportsRawMode
    check not fallback.capabilities.supportsResizeEvents
    fallback.close()

    var strict = defaults
    strict.requireTerminal = true
    expect PromptIOError:
      discard openTerminalScreenSessionWithCapabilities(
        stdin, stdout, strict, capabilities, failTerminalSetup)

  test "secret terminal input never falls back to echoing after setup fails":
    for ansi in [false, true]:
      let capabilities = PromptCapabilities(inputIsTerminal: true,
        outputIsTerminal: true, supportsAnsi: ansi, supportsRawMode: true)
      expect PromptIOError:
        discard openTerminalScreenSessionWithCapabilities(
          stdin, stdout, defaultPromptSessionOptions(), capabilities,
          failTerminalSetup, secretInput = true)

  test "secret redirected input still uses ordinary line reads":
    let inputTemp = createTempFile("terminal_prompt_secret_input_", ".txt")
    let outputTemp = createTempFile("terminal_prompt_secret_output_", ".txt")
    defer:
      inputTemp.cfile.close()
      outputTemp.cfile.close()
      removeFile(inputTemp.path)
      removeFile(outputTemp.path)
    inputTemp.cfile.write("test-secret\nlater\n")
    inputTemp.cfile.setFilePos(0)
    let promptSession = openTerminalScreenSession(inputTemp.cfile,
      outputTemp.cfile, secretInput = true)
    check runPasswordPrompt(promptSession,
      initPasswordPromptOptions("Password")).value == "test-secret"
    check inputTemp.cfile.readLine() == "later"

suite "normalized input engine":
  test "default bindings resolve shared prompt actions":
    let expected = @[
      (types.keyEnter, actionSubmit),
      (types.keyEscape, actionCancel),
      (types.keyCtrlC, actionCancel),
      (types.keyArrowUp, actionMoveUp),
      (types.keyArrowDown, actionMoveDown),
      (types.keyArrowLeft, actionMoveLeft),
      (types.keyArrowRight, actionMoveRight),
      (types.keyHome, actionMoveFirst),
      (types.keyEnd, actionMoveLast),
      (types.keyBackspace, actionDeleteBackward),
      (types.keyDelete, actionDeleteForward),
      (types.keySpace, actionToggle),
      (types.keyText, actionSelectAll),
      (types.keyText, actionClearSelection)
    ]
    var events: seq[PromptInputEvent]
    for item in expected:
      case item[0]
      of types.keyCtrlC:
        events.add keys.keyInput(item[0], modifiers = {types.modifierCtrl})
      of types.keySpace:
        events.add keys.keyInput(item[0], text = " ")
      of types.keyText:
        let value = if item[1] == actionSelectAll: "a" else: "c"
        events.add keys.keyInput(item[0], text = value)
      else:
        events.add keys.keyInput(item[0])
    let scripted = newScriptedSession(events)
    let engine = newPromptInputEngine(PromptIO(scripted))
    for item in expected:
      let event = engine.readInput()
      check event.kind == engineAction
      check event.action == item[1]
      check event.actionKey.key == item[0]

  test "text, Tab, EOF, timeout, and resize remain available":
    let scripted = newScriptedSession(@[
      keys.keyInput(types.keyText, text = "é", sequence = "é"),
      keys.keyInput(types.keyTab),
      keys.resizeInput(100, 40),
      keys.timeoutInput(),
      keys.endInput()
    ])
    let engine = newPromptInputEngine(PromptIO(scripted))
    let textEvent = engine.readInput()
    check textEvent.kind == engineKey
    check textEvent.key.text == "é"
    check textEvent.key.sequence == "é"
    let tabEvent = engine.readInput()
    check tabEvent.kind == engineKey
    check tabEvent.key.key == types.keyTab
    let resized = engine.readInput()
    check resized.kind == engineResize
    check resized.size == PromptSize(columns: 100, rows: 40)
    check engine.readInput().kind == engineTimeout
    check engine.readInput().kind == engineEndOfInput

  test "custom text bindings match payload and modifiers exactly":
    var bindings = defaultPromptKeyBindings()
    bindings.submit.add keyBinding(types.keyText, "s", {types.modifierCtrl})
    let event = PromptKeyEvent(key: types.keyText, text: "s",
      modifiers: {types.modifierCtrl})
    check event.resolveAction(bindings).get() == actionSubmit
    check event.matches(keyBinding(types.keyText, "s", {types.modifierCtrl}))
    check not event.matches(keyBinding(types.keyText, "s"))

  test "injected input failures propagate and the session still closes":
    let scripted = newScriptedSession()
    scripted.failRead = true
    var caught = false
    try:
      withPromptSession(PromptSession(scripted)):
        discard newPromptInputEngine(PromptIO(scripted)).readInput()
    except PromptIOError:
      caught = true
    check caught
    check scripted.closeCount == 1

suite "cursor-safe prompt display":
  test "interactive redraw erases wrapped Unicode frames":
    let scripted = newScriptedSession(mode = promptInteractiveMode)
    let display = newPromptDisplay(PromptIO(scripted), scripted.mode,
      some(PromptSize(columns: 4, rows: 24)))
    display.redraw("12345\n界")
    display.redraw("next")
    display.close()
    let eraseThreeRows = "\r\e[2K\e[1A\r\e[2K\e[1A\r\e[2K"
    check scripted.output == "12345\n界" & eraseThreeRows & "next" &
      "\r\e[2K"
    check scripted.flushCount == 3

  test "line mode preserves history and emits no ANSI controls":
    let scripted = newScriptedSession()
    let display = newPromptDisplay(PromptIO(scripted), scripted.mode)
    display.redraw("first")
    display.redraw("second")
    display.close()
    check scripted.output == "first\nsecond\n"
    check '\e' notin scripted.output

  test "finish replaces an interactive frame with permanent output":
    let scripted = newScriptedSession(mode = promptInteractiveMode)
    let display = newPromptDisplay(PromptIO(scripted), scripted.mode)
    display.redraw("working")
    display.finish("done")
    display.close()
    check scripted.output == "working\r\e[2Kdone\n"
    check scripted.flushCount == 3

  test "display and session cleanup run after an injected exception":
    let scripted = newScriptedSession(mode = promptInteractiveMode)
    var caught = false
    try:
      withPromptSession(PromptSession(scripted)):
        let display = newPromptDisplay(PromptIO(scripted), scripted.mode)
        withPromptDisplay(display):
          display.redraw("temporary")
          raise newException(ValueError, "injected failure")
    except ValueError:
      caught = true
    check caught
    check scripted.output == "temporary\r\e[2K"
    check scripted.closeCount == 1

  test "session cleanup still runs when display output fails":
    let scripted = newScriptedSession(mode = promptInteractiveMode)
    scripted.failWrite = true
    var caught = false
    try:
      withPromptSession(PromptSession(scripted)):
        let display = newPromptDisplay(PromptIO(scripted), scripted.mode)
        withPromptDisplay(display):
          display.redraw("temporary")
    except PromptIOError:
      caught = true
    check caught
    check scripted.closeCount == 1

suite "TerminalScreen key adapter coverage":
  test "every normalized key retains its meaning":
    let pairs = @[
      (screen.keyUnknown, types.keyUnknown),
      (screen.keyText, types.keyText),
      (screen.keySpace, types.keySpace),
      (screen.keyEnter, types.keyEnter),
      (screen.keyEscape, types.keyEscape),
      (screen.keyTab, types.keyTab),
      (screen.keyBacktab, types.keyBacktab),
      (screen.keyBackspace, types.keyBackspace),
      (screen.keyDelete, types.keyDelete),
      (screen.keyInsert, types.keyInsert),
      (screen.keyHome, types.keyHome),
      (screen.keyEnd, types.keyEnd),
      (screen.keyArrowUp, types.keyArrowUp),
      (screen.keyArrowDown, types.keyArrowDown),
      (screen.keyArrowLeft, types.keyArrowLeft),
      (screen.keyArrowRight, types.keyArrowRight),
      (screen.keyPageUp, types.keyPageUp),
      (screen.keyPageDown, types.keyPageDown),
      (screen.keyCtrlC, types.keyCtrlC),
      (screen.keyCtrlD, types.keyCtrlD)
    ]
    check pairs.len == ord(high(screen.Key)) - ord(low(screen.Key)) + 1
    check pairs.len == ord(high(types.PromptKey)) -
      ord(low(types.PromptKey)) + 1
    for item in pairs:
      check toPromptEvent(screen.keyInput(item[0])).keyEvent.key == item[1]
    check toPromptEvent(screen.endOfInput()).kind == keys.inputEndOfInput

when defined(posix):
  import std/[posix, termios]

  when defined(linux):
    {.passL: "-lutil".}

  when defined(macosx):
    proc openpty(master, slave: ptr cint; name: cstring;
                 settings: ptr Termios; size: pointer): cint {.
      importc, header: "<util.h>".}

    var PENDIN {.importc, header: "<termios.h>".}: Cflag
  else:
    proc openpty(master, slave: ptr cint; name: cstring;
                 settings: ptr Termios; size: pointer): cint {.
      importc, header: "<pty.h>".}

  type Pty = object
    master: cint
    slave: File

  proc openPty(): Pty =
    var slaveFd: cint
    if openpty(addr result.master, addr slaveFd, nil, nil, nil) != 0:
      raiseOSError(osLastError())
    if not open(result.slave, FileHandle(slaveFd), fmReadWrite):
      discard posix.close(result.master)
      discard posix.close(slaveFd)
      raise newException(IOError, "cannot wrap PTY slave file descriptor")

  proc close(pty: var Pty) =
    pty.slave.close()
    discard posix.close(pty.master)

  proc readAvailable(fd: cint): string =
    let flags = fcntl(fd, F_GETFL, 0)
    discard fcntl(fd, F_SETFL, flags or O_NONBLOCK)
    var buffer: array[4096, char]
    while true:
      let count = posix.read(fd, addr buffer[0], buffer.len)
      if count <= 0:
        break
      for index in 0 ..< count:
        result.add buffer[index]

  suite "POSIX prompt session integration":
    test "public password fallback suppresses echo for dumb and redirected output":
      let originalTerm = getEnv("TERM")
      let hadTerm = existsEnv("TERM")
      defer:
        if hadTerm: putEnv("TERM", originalTerm)
        else: delEnv("TERM")
      for redirectedOutput in [false, true]:
        putEnv("TERM", if redirectedOutput: "xterm" else: "dumb")
        var pty = openPty()
        let outputTemp = createTempFile("terminal_prompt_public_password_", ".txt")
        defer:
          pty.close()
          outputTemp.cfile.close()
          removeFile(outputTemp.path)
        let slaveFd = cint(pty.slave.getFileHandle())
        var original: Termios
        check tcGetAttr(slaveFd, addr original) == 0
        check (original.c_lflag and ECHO) != 0
        let child = fork()
        if child < 0:
          raiseOSError(osLastError())
        if child == 0:
          # Wait until askPassword owns terminal state before sending input.
          # On regression, still send a line after the timeout so the test fails
          # without leaving the parent blocked in a canonical read.
          var echoSuppressed = false
          for _ in 0 ..< 200:
            var mode: Termios
            if tcGetAttr(slaveFd, addr mode) == 0 and
                (mode.c_lflag and ECHO) == 0:
              echoSuppressed = true
              break
            discard usleep(10_000)
          let bytes = "test-secret\n"
          let written = posix.write(pty.master, unsafeAddr bytes[0], bytes.len)
          exitnow(if echoSuppressed and written == bytes.len: 0 else: 1)
        let output = if redirectedOutput: outputTemp.cfile else: pty.slave
        let response = askPassword(initPasswordPromptOptions("Password",
          runtime = defaultRuntimeOptions(pty.slave, output)))
        check response.value == "test-secret"
        var childStatus: cint
        check waitpid(child, childStatus, 0) == child
        check childStatus == 0
        var restored: Termios
        check tcGetAttr(slaveFd, addr restored) == 0
        check (restored.c_lflag and ECHO) == (original.c_lflag and ECHO)
        outputTemp.cfile.flushFile()
        let captured = pty.master.readAvailable() & readFile(outputTemp.path)
        check "test-secret" notin captured
        check '\e' notin captured

    test "plain password input suppresses echo and restores modes on every exit":
      for redirectedOutput in [false, true]:
        for outcome in ["answer", "retry", "cancel", "eof", "exception"]:
          var pty = openPty()
          let outputTemp = createTempFile("terminal_prompt_password_", ".txt")
          defer:
            pty.close()
            outputTemp.cfile.close()
            removeFile(outputTemp.path)
          let slaveFd = cint(pty.slave.getFileHandle())
          var original: Termios
          check tcGetAttr(slaveFd, addr original) == 0
          original.c_lflag = original.c_lflag or Cflag(ECHO or ECHONL)
          check tcSetAttr(slaveFd, TCSANOW, addr original) == 0
          var options = defaultPromptSessionOptions()
          if not redirectedOutput:
            options.ansiMode = promptAnsiNever
          let output = if redirectedOutput: outputTemp.cfile else: pty.slave
          let promptSession = openTerminalScreenSession(pty.slave, output,
            options, secretInput = true)
          defer: promptSession.close()
          check promptSession.mode == promptLineMode
          var raw: Termios
          check tcGetAttr(slaveFd, addr raw) == 0
          check (raw.c_lflag and Cflag(ECHO or ECHONL)) == 0
          let bytes = case outcome
            of "cancel": "partial-secret\x03"
            of "eof": "\x04"
            of "retry": "rejected-secret\rtest-secret\r"
            else: "test-secret\r"
          check posix.write(pty.master, unsafeAddr bytes[0], bytes.len) ==
            bytes.len
          let validator: Validator[string] = proc(value: string): string =
            if outcome == "exception":
              raise newException(ValueError, "rejected " & value)
            if value == "rejected-secret": "Try again" else: ""
          let passwordOptions = initPasswordPromptOptions("Password",
            validator = validator)
          if outcome == "exception":
            expect PromptError:
              discard runPasswordPrompt(promptSession, passwordOptions)
          else:
            let response = runPasswordPrompt(promptSession, passwordOptions)
            case outcome
            of "cancel": check response.isCancelled
            of "eof": check response.isEndOfInput
            else: check response.value == "test-secret"

          var restored: Termios
          check tcGetAttr(slaveFd, addr restored) == 0
          check restored.c_iflag == original.c_iflag
          check restored.c_oflag == original.c_oflag
          check restored.c_cflag == original.c_cflag
          when defined(macosx):
            check (restored.c_lflag and not PENDIN) ==
              (original.c_lflag and not PENDIN)
          else:
            check restored.c_lflag == original.c_lflag
          check restored.c_cc == original.c_cc
          outputTemp.cfile.flushFile()
          let captured = pty.master.readAvailable() & readFile(outputTemp.path)
          check "secret" notin captured
          check '\e' notin captured
          if outcome == "retry":
            check "Try again" in captured

    test "adapter decodes cancellation and restores raw mode after failure":
      var pty = openPty()
      defer: pty.close()
      let slaveFd = cint(pty.slave.getFileHandle())
      var original: Termios
      check tcGetAttr(slaveFd, addr original) == 0
      var options = defaultPromptSessionOptions()
      options.ansiMode = promptAnsiAlways

      var caught = false
      try:
        let promptSession = openTerminalScreenSession(
          pty.slave, pty.slave, options)
        withPromptSession(promptSession):
          check promptSession.mode == promptInteractiveMode
          var raw: Termios
          check tcGetAttr(slaveFd, addr raw) == 0
          check (raw.c_lflag and ICANON) == 0
          check (raw.c_lflag and ECHO) == 0
          let bytes = "\x03"
          check posix.write(pty.master, unsafeAddr bytes[0], bytes.len) ==
            bytes.len
          let event = newPromptInputEngine(PromptIO(promptSession)).readInput(200)
          check event.kind == engineAction
          check event.action == actionCancel
          raise newException(ValueError, "injected failure")
      except ValueError:
        caught = true
      check caught

      var restored: Termios
      check tcGetAttr(slaveFd, addr restored) == 0
      check restored.c_iflag == original.c_iflag
      check restored.c_oflag == original.c_oflag
      check restored.c_cflag == original.c_cflag
      when defined(macosx):
        # XNU sets PENDIN when canonical mode is restored with queued input.
        # It is kernel-maintained state, not a setting changed by the session.
        check (restored.c_lflag and not PENDIN) ==
          (original.c_lflag and not PENDIN)
      else:
        check restored.c_lflag == original.c_lflag
      check restored.c_cc == original.c_cc
