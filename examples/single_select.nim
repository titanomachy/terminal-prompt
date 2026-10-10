## Typed choices, hints, and disabled entries.
## Run: nim r --path:src examples/single_select.nim

import std/options
import terminal_prompt

when isMainModule:
  let response = askSelect(initSelectPromptOptions("Port", @[
    choice("HTTP", 80),
    choice("HTTPS", 443, hint = "recommended"),
    choice("Legacy", 8080, disabled = true)
  ], initialIndex = some(1)))
  if response.isAnswered:
    echo "Port: ", response.value
