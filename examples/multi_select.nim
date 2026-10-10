## Choose zero or more features, returned in choice order.
## Run: nim r --path:src examples/multi_select.nim

import std/strutils
import terminal_prompt

when isMainModule:
  let response = askMultiSelect(initMultiSelectPromptOptions("Features", @[
    choice("Documentation", "docs"),
    choice("Tests", "tests"),
    choice("Examples", "examples")
  ], initiallySelected = @[0]))
  if response.isAnswered:
    echo "Enabled: ", response.value.join(", ")
