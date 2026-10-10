## Masked entry. Never print the returned secret.
## Run: nim r --path:src examples/password_prompt.nim

import terminal_prompt

when isMainModule:
  let response = askPassword("Publishing token", mask = "•")
  if response.isAnswered:
    echo "Token received."
