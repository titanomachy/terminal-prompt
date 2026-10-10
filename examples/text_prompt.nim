## Text entry with a placeholder and validation.
## Run: nim r --path:src examples/text_prompt.nim

import terminal_prompt

proc requireName(value: string): string =
  if value.len == 0: "Enter a project name." else: ""

when isMainModule:
  let response = askText("Project name", placeholder = "my-project",
    validator = requireName)
  if response.isAnswered:
    echo "Creating ", response.value
