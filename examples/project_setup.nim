## A small interactive setup wizard using every core prompt type.

import std/options

import terminal_prompt

proc requireNonEmpty(value: string): string =
  if value.len == 0: "Enter a value." else: ""

proc answerOrQuit[T](response: PromptResult[T]; step: string): T =
  case response.status
  of promptAnswered:
    response.value
  of promptCancelled:
    quit("Setup cancelled " & step & ".")
  of promptEndOfInput:
    quit("Input closed " & step & ".")

when isMainModule:
  let project = askText("Project name", default = "my-project",
    validator = requireNonEmpty).answerOrQuit(
      "before a project name was chosen")

  let language = askSelect(initSelectPromptOptions("Language", @[
    choice("Nim", "nim", hint = "recommended"),
    choice("C", "c"),
    choice("Other", "other")
  ], initialIndex = some(0))).answerOrQuit(
    "before a language was chosen")

  let features = askMultiSelect(initMultiSelectPromptOptions("Features", @[
    choice("Documentation", "docs"),
    choice("Tests", "tests"),
    choice("Examples", "examples")
  ], initiallySelected = @[0, 1])).answerOrQuit(
    "before features were chosen")

  discard askPassword("Optional publishing token", mask = "•").answerOrQuit(
    "while reading the token")

  let confirmed = askConfirm("Create " & project & "?", default = true).
    answerOrQuit("before confirmation")
  if confirmed:
    echo "Creating ", project, " (", language, ") with ",
      features.len, " feature(s)."
