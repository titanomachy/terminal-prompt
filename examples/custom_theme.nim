## A runnable prompt with a custom semantic TerminalStyle theme.

import terminal_prompt
import terminal_style

when isMainModule:
  var theme = defaultPromptTheme()
  theme.question = initTerminalStyle(
    foreground = rgbColor(120, 200, 255),
    attributes = {taBold}
  )
  theme.answer = initTerminalStyle(foreground = colorBrightGreen)
  theme.error = initTerminalStyle(
    foreground = colorBrightRed,
    attributes = {taBold}
  )

  let response = askText("Display name",
    helpText = "Shown in generated project metadata", theme = theme)
  case response.status
  of promptAnswered:
    echo "Hello, ", response.value
  of promptCancelled:
    echo "cancelled"
  of promptEndOfInput:
    echo "input closed"
