## A small interactive setup wizard using every core prompt type.

import std/options

import terminal_prompt

proc requireNonEmpty(value: string): string =
  if value.len == 0: "Enter a value." else: ""

when isMainModule:
  let project = askText("Project name", default = "my-project",
    validator = requireNonEmpty)
  if not project.isAnswered:
    quit("Setup cancelled before a project name was chosen.")

  let language = askSelect(initSelectPromptOptions("Language", @[
    choice("Nim", "nim", hint = "recommended"),
    choice("C", "c"),
    choice("Other", "other")
  ], initialIndex = some(0)))
  if not language.isAnswered:
    quit("Setup cancelled before a language was chosen.")

  let features = askMultiSelect(initMultiSelectPromptOptions("Features", @[
    choice("Documentation", "docs"),
    choice("Tests", "tests"),
    choice("Examples", "examples")
  ], initiallySelected = @[0, 1]))
  if not features.isAnswered:
    quit("Setup cancelled before features were chosen.")

  let token = askPassword("Optional publishing token", mask = "•")
  if not token.isAnswered:
    quit("Setup cancelled while reading the token.")

  let confirmed = askConfirm("Create " & project.value & "?", default = true)
  if confirmed.valueOr(false):
    echo "Creating ", project.value, " (", language.value, ") with ",
      features.value.len, " feature(s)."
