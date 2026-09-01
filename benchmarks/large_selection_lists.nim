## Repeatable large-list benchmark used to evaluate whether filtering belongs
## in the core selection prompt.

import std/[options, strformat, times]

import terminal_prompt/[keys, select_prompt, session, types]

import ../tests/support/scripted_session

proc runBenchmark(count: int): float =
  var choices = newSeqOfCap[PromptChoice[int]](count)
  for index in 1 .. count:
    choices.add choice("Choice " & $index, index)

  let scripted = newScriptedSession(@[
    keyInput(keyArrowDown), keyInput(keyEnter)
  ], mode = promptInteractiveMode,
    size = some(PromptSize(columns: 80, rows: 24)))
  let started = cpuTime()
  let response = runSelectPrompt(PromptSession(scripted),
    initSelectPromptOptions("Benchmark", choices))
  result = cpuTime() - started
  doAssert response.value == 2

when isMainModule:
  echo "Large interactive selection benchmark (viewport: 22 rows)"
  for count in [100, 1_000, 10_000, 100_000]:
    echo &"{count:>7} choices: {runBenchmark(count) * 1000:>9.3f} ms"
