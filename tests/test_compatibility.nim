## Tests cross-platform rendering, Unicode, scale, and redirected workflows.

import std/[options, os, strutils, tempfiles, unicode, unittest]

import terminal_style

import terminal_prompt
import terminal_prompt/[keys, render, select_prompt, session, types]

import ./support/scripted_session

proc enter(): PromptInputEvent =
  keyInput(keyEnter)

suite "cross-platform compatibility":
  test "ANSI-disabled semantic rendering preserves only plain content":
    let renderer = newSemanticRenderer()
    let rendered = renderer.render(frame(@[
      segment(roleQuestion, "Question"),
      segment(rolePlain, ": "),
      segment(roleAnswer, "answer"),
      segment(roleHint, " (hint)"),
      segment(roleError, " error")
    ]), defaultPromptTheme(), ansi = false)
    check rendered == "Question: answer (hint) error"
    check '\e' notin rendered

  test "narrow resized terminals keep Unicode labels valid and selectable":
    let scripted = newScriptedSession(@[
      resizeInput(8, 4), keyInput(keyArrowDown), enter()
    ], mode = promptInteractiveMode,
      size = some(PromptSize(columns: 12, rows: 5)))
    let response = runSelectPrompt(PromptSession(scripted),
      initSelectPromptOptions("言語を選ぶ", @[
        choice("日本語の界面", "ja"),
        choice("Emoji 👩‍💻 tools", "emoji"),
        choice("Français", "fr")
      ]))
    check response.value == "emoji"
    check scripted.output.validateUtf8 == -1
    check "? 言語を選ぶ: Emoji 👩‍💻 tools" in
        scripted.output.stripAnsi
    check "\e[2K" in scripted.output
    check scripted.closeCount == 1

  test "large interactive lists render only the active viewport":
    var choices: seq[PromptChoice[int]]
    for index in 1 .. 10_000:
      choices.add choice("Choice " & $index, index)
    let scripted = newScriptedSession(@[
      keyInput(keyArrowDown), enter()
    ], mode = promptInteractiveMode,
      size = some(PromptSize(columns: 80, rows: 5)))
    let response = runSelectPrompt(PromptSession(scripted),
      initSelectPromptOptions("Large list", choices))
    check response.value == 2
    check "[2/10000]" in scripted.output.stripAnsi
    check "Choice 9999" notin scripted.output
    check scripted.output.len < 2_000

  test "all public prompts share a plain redirected-stream workflow":
    let inputTemp = createTempFile("terminal_prompt_compat_input_", ".txt")
    let outputTemp = createTempFile("terminal_prompt_compat_output_", ".txt")
    defer:
      inputTemp.cfile.close()
      outputTemp.cfile.close()
      removeFile(inputTemp.path)
      removeFile(outputTemp.path)
    inputTemp.cfile.write("Zoë 界\nsëcret\noui\n2\n1, 3\n")
    inputTemp.cfile.flushFile()
    inputTemp.cfile.setFilePos(0)
    let runtime = defaultRuntimeOptions(inputTemp.cfile, outputTemp.cfile)

    check askText(initTextPromptOptions("Name", runtime = runtime)).value ==
      "Zoë 界"
    check askPassword(initPasswordPromptOptions("Password",
      runtime = runtime)).value == "sëcret"
    check askConfirm(initConfirmPromptOptions("Continue",
      yesLabel = "Oui", noLabel = "Non", runtime = runtime)).value
    check askSelect(initSelectPromptOptions("Color", @[
      choice("Rouge", "red"), choice("Blå", "blue")
    ], runtime = runtime)).value == "blue"
    check askMultiSelect(initMultiSelectPromptOptions("Features", @[
      choice("Docs", "docs"), choice("Tests", "tests"),
      choice("Examples", "examples")
    ], runtime = runtime)).value == @["docs", "examples"]

    outputTemp.cfile.flushFile()
    let output = readFile(outputTemp.path)
    check output.validateUtf8 == -1
    check "Zoë 界" in output
    check "sëcret" notin output
    check '\e' notin output

  test "ANSI capability loss selects line mode on every platform":
    let capabilities = PromptCapabilities(inputIsTerminal: true,
      outputIsTerminal: true, supportsAnsi: false, supportsRawMode: true,
      supportsResizeEvents: true)
    check capabilities.selectSessionMode() == promptLineMode
