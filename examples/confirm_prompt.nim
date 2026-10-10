## Confirmation with a safe default.
## Run: nim r --path:src examples/confirm_prompt.nim

import terminal_prompt

when isMainModule:
  let response = askConfirm("Create project?", default = false)
  if response.isAnswered:
    echo (if response.value: "Creating project." else: "Skipped.")
