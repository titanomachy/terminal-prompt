## A line-oriented workflow suitable for pipes and automation.
##
## Prompts go to stderr, leaving stdout available for the final machine-readable
## value. For example: ``printf 'nightly\n2\n' | ./redirected_workflow``.

import terminal_prompt

proc answerOrQuit[T](response: PromptResult[T]; name: string): T =
  case response.status
  of promptAnswered:
    response.value
  of promptCancelled:
    quit(name & " was cancelled")
  of promptEndOfInput:
    quit("input ended while reading " & name)

when isMainModule:
  let runtime = defaultRuntimeOptions(input = stdin, output = stderr)
  let releaseName = askText(initTextPromptOptions("Release name",
    runtime = runtime)).answerOrQuit("release name")
  let channel = askSelect(initSelectPromptOptions("Channel", @[
    choice("Stable", "stable"),
    choice("Preview", "preview")
  ], runtime = runtime)).answerOrQuit("channel")

  echo releaseName, "\t", channel
