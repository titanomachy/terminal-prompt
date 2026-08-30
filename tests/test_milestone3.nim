import std/[options, os, strutils, tempfiles, unittest]

import terminal_style

import terminal_prompt
import terminal_prompt/[io, keys, multiselect_prompt, select_prompt, session,
  terminal_screen_adapter, types]

import ./support/scripted_session

proc text(value: string): PromptInputEvent =
  keyInput(keyText, text = value, sequence = value)

proc enter(): PromptInputEvent =
  keyInput(keyEnter)

proc down(): PromptInputEvent =
  keyInput(keyArrowDown)

proc cancel(): PromptInputEvent =
  keyInput(keyEscape)

suite "single-select prompt":
  test "navigation skips disabled choices and wraps by default":
    let scripted = newScriptedSession(@[down(), down(), enter()],
      mode = promptInteractiveMode)
    let response = runSelectPrompt(PromptSession(scripted),
      initSelectPromptOptions("Pick", @[
        choice("One", 1), choice("Two", 2, disabled = true),
        choice("Three", 3)
      ]))
    check response.value == 1
    check "(disabled)" in scripted.output.stripAnsi
    check scripted.closeCount == 1

  test "non-wrapping navigation stops at the last enabled choice":
    let scripted = newScriptedSession(@[down(), enter()],
      mode = promptInteractiveMode)
    let response = runSelectPrompt(PromptSession(scripted),
      initSelectPromptOptions("Pick", @[
        choice("One", 1), choice("Two", 2)
      ], initialIndex = some(1), wrapNavigation = false))
    check response.value == 2

  test "Home and End move to the first and last enabled choices":
    let toLast = newScriptedSession(@[keyInput(keyEnd), enter()],
      mode = promptInteractiveMode)
    check runSelectPrompt(PromptSession(toLast),
      initSelectPromptOptions("Pick", @[
        choice("One", 1, disabled = true), choice("Two", 2),
        choice("Three", 3)
      ])).value == 3

    let toFirst = newScriptedSession(@[keyInput(keyHome), enter()],
      mode = promptInteractiveMode)
    check runSelectPrompt(PromptSession(toFirst),
      initSelectPromptOptions("Pick", @[
        choice("One", 1, disabled = true), choice("Two", 2),
        choice("Three", 3)
      ], initialIndex = some(2))).value == 2

  test "a resized short terminal keeps the focused choice in its viewport":
    var choices: seq[PromptChoice[int]]
    for index in 1 .. 8:
      choices.add choice("Item " & $index, index)
    let scripted = newScriptedSession(@[
      down(), down(), resizeInput(40, 4), down(), down(), enter()
    ], mode = promptInteractiveMode,
      size = some(PromptSize(columns: 80, rows: 5)))
    let response = runSelectPrompt(PromptSession(scripted),
      initSelectPromptOptions("Pick", choices))
    check response.value == 5
    check "[5/8]" in scripted.output.stripAnsi
    check "Item 5" in scripted.output.stripAnsi

  test "line mode accepts one-based indices and retries invalid choices":
    let scripted = newScriptedSession(@[
      text("2"), enter(), text("3"), enter()
    ])
    let response = runSelectPrompt(PromptSession(scripted),
      initSelectPromptOptions("Pick", @[
        choice("One", 1), choice("Two", 2, disabled = true),
        choice("Three", 3)
      ]))
    check response.value == 3
    check "Choice 2 is disabled." in scripted.output
    check '\e' notin scripted.output

  test "blank line-mode submission uses the configured initial choice":
    let scripted = newScriptedSession(@[enter()])
    check runSelectPrompt(PromptSession(scripted),
      initSelectPromptOptions("Pick", @[
        choice("One", 1), choice("Two", 2)
      ], initialIndex = some(1))).value == 2

  test "cancel and EOF remain distinct":
    let cancelledSession = newScriptedSession(@[cancel()])
    check runSelectPrompt(PromptSession(cancelledSession),
      initSelectPromptOptions("Pick", @[choice("One", 1)])).isCancelled
    let eofSession = newScriptedSession(@[endInput()])
    check runSelectPrompt(PromptSession(eofSession),
      initSelectPromptOptions("Pick", @[choice("One", 1)])).isEndOfInput

suite "multi-select prompt":
  test "toggle, select-all, clear, and explicit submission compose":
    let scripted = newScriptedSession(@[
      down(), keyInput(keySpace, text = " "), text("a"), text("c"),
      keyInput(keySpace, text = " "), enter()
    ], mode = promptInteractiveMode)
    let response = runMultiSelectPrompt(PromptSession(scripted),
      initMultiSelectPromptOptions("Features", @[
        choice("A", "a"), choice("B", "b", disabled = true),
        choice("C", "c"), choice("D", "d")
      ], initiallySelected = @[0]))
    check response.value == @["c"]
    check "[x]" in scripted.output.stripAnsi

  test "select-all excludes disabled choices":
    let scripted = newScriptedSession(@[text("a"), enter()],
      mode = promptInteractiveMode)
    let response = runMultiSelectPrompt(PromptSession(scripted),
      initMultiSelectPromptOptions("Features", @[
        choice("A", "a"), choice("B", "b", disabled = true),
        choice("C", "c")
      ]))
    check response.value == @["a", "c"]

  test "select-all and clear use replaceable action bindings":
    var bindings = defaultPromptKeyBindings()
    bindings.selectAll = @[keyBinding(keyText, text = "*")]
    bindings.clearSelection = @[keyBinding(keyText, text = "-")]
    let scripted = newScriptedSession(@[
      text("*"), text("-"), text("*"), enter()
    ], mode = promptInteractiveMode)
    let response = runMultiSelectPrompt(PromptSession(scripted),
      initMultiSelectPromptOptions("Features", @[
        choice("A", "a"), choice("B", "b")
      ], runtime = defaultRuntimeOptions(keyBindings = bindings)))
    check response.value == @["a", "b"]
    check "* all" in scripted.output.stripAnsi
    check "- clear" in scripted.output.stripAnsi

  test "Enter submits defaults without toggling them":
    let scripted = newScriptedSession(@[enter()],
      mode = promptInteractiveMode)
    let response = runMultiSelectPrompt(PromptSession(scripted),
      initMultiSelectPromptOptions("Features", @[
        choice("A", "a"), choice("B", "b"), choice("C", "c")
      ], initiallySelected = @[0, 2]))
    check response.value == @["a", "c"]

  test "line mode accepts comma or space separated one-based indices":
    let scripted = newScriptedSession(@[
      text("1"), text(","), text(" "), text("3"), enter()
    ])
    let response = runMultiSelectPrompt(PromptSession(scripted),
      initMultiSelectPromptOptions("Features", @[
        choice("A", "a"), choice("B", "b"), choice("C", "c")
      ]))
    check response.value == @["a", "c"]
    check "A, C" in scripted.output

  test "line mode rejects disabled and out-of-range indices":
    let scripted = newScriptedSession(@[
      text("2"), enter(), text("9"), enter(), text("3"), enter()
    ])
    let response = runMultiSelectPrompt(PromptSession(scripted),
      initMultiSelectPromptOptions("Features", @[
        choice("A", "a"), choice("B", "b", disabled = true),
        choice("C", "c")
      ]))
    check response.value == @["c"]
    check "Choice 2 is disabled." in scripted.output
    check "between 1 and 3" in scripted.output

  test "empty and all-disabled lists explicitly submit an empty answer":
    let emptySession = newScriptedSession(@[enter()])
    check runMultiSelectPrompt(PromptSession(emptySession),
      initMultiSelectPromptOptions("Nothing", newSeq[PromptChoice[int]]())).value ==
      newSeq[int]()

    let disabledSession = newScriptedSession(@[enter()])
    check runMultiSelectPrompt(PromptSession(disabledSession),
      initMultiSelectPromptOptions("Nothing", @[
        choice("Unavailable", 1, disabled = true)
      ])).value == newSeq[int]()

  test "toggle without submission does not turn EOF into an answer":
    let scripted = newScriptedSession(@[
      keyInput(keySpace, text = " "), endInput()
    ], mode = promptInteractiveMode)
    check runMultiSelectPrompt(PromptSession(scripted),
      initMultiSelectPromptOptions("Features", @[
        choice("A", "a")
      ])).isEndOfInput

suite "selection configuration and public fallback":
  test "invalid defaults and empty single-select lists close direct sessions":
    let emptySession = newScriptedSession()
    expect PromptConfigurationError:
      discard runSelectPrompt(PromptSession(emptySession),
        initSelectPromptOptions("Pick", newSeq[PromptChoice[int]]()))
    check emptySession.closeCount == 1

    let disabledSession = newScriptedSession()
    expect PromptConfigurationError:
      discard runSelectPrompt(PromptSession(disabledSession),
        initSelectPromptOptions("Pick", @[
          choice("Unavailable", 1, disabled = true)
        ]))
    check disabledSession.closeCount == 1

    let multiSession = newScriptedSession()
    expect PromptConfigurationError:
      discard runMultiSelectPrompt(PromptSession(multiSession),
        initMultiSelectPromptOptions("Pick", @[
          choice("One", 1)
        ], initiallySelected = @[0, 0]))
    check multiSession.closeCount == 1

  test "public APIs consume separate redirected input lines":
    let inputTemp = createTempFile("terminal_prompt_m3_input_", ".txt")
    let outputTemp = createTempFile("terminal_prompt_m3_output_", ".txt")
    defer:
      inputTemp.cfile.close()
      outputTemp.cfile.close()
      removeFile(inputTemp.path)
      removeFile(outputTemp.path)
    inputTemp.cfile.write("2\n1,3\n")
    inputTemp.cfile.flushFile()
    inputTemp.cfile.setFilePos(0)
    let runtime = defaultRuntimeOptions(inputTemp.cfile, outputTemp.cfile)

    check askSelect(initSelectPromptOptions("Color", @[
      choice("Red", "red"), choice("Blue", "blue")
    ], runtime = runtime)).value == "blue"
    check askMultiSelect(initMultiSelectPromptOptions("Features", @[
      choice("Docs", "docs"), choice("Tests", "tests"),
      choice("Examples", "examples")
    ], runtime = runtime)).value == @["docs", "examples"]

    outputTemp.cfile.flushFile()
    let output = readFile(outputTemp.path)
    check "Blue" in output
    check "Docs, Examples" in output
    check '\e' notin output

when defined(posix):
  import std/[posix, termios]

  when defined(linux):
    {.passL: "-lutil".}

  when defined(macosx):
    proc openpty(master, slave: ptr cint; name: cstring;
                 settings: ptr Termios; size: pointer): cint {.
      importc, header: "<util.h>".}
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

  suite "POSIX selection PTY integration":
    test "interactive redraw preserves output before and after the prompt":
      var pty = openPty()
      defer: pty.close()
      var sessionOptions = defaultPromptSessionOptions()
      sessionOptions.ansiMode = promptAnsiAlways
      let promptSession = openTerminalScreenSession(
        pty.slave, pty.slave, sessionOptions)
      promptSession.write("before\n")
      promptSession.flush()
      let input = "\e[B\r"
      check posix.write(pty.master, unsafeAddr input[0], input.len) == input.len

      let response = runSelectPrompt(promptSession,
        initSelectPromptOptions("Pick", @[
          choice("One", 1), choice("Two", 2)
        ]))
      check response.value == 2
      pty.slave.write("after\n")
      pty.slave.flushFile()

      let captured = pty.master.readAvailable()
      let plain = captured.stripAnsi
      check plain.find("before") >= 0
      check plain.find("? Pick: Two") > plain.find("before")
      check plain.find("after") > plain.find("? Pick: Two")
      check "\e[2K" in captured
