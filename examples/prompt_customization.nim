## Semantic colors, help text, custom output, and an extra submit binding.
## Run: nim r --path:src examples/prompt_customization.nim

import terminal_prompt
import terminal_style

when isMainModule:
  var theme = defaultPromptTheme()
  theme.question = initTerminalStyle(
    foreground = rgbColor(120, 200, 255), attributes = {taBold})
  theme.answer = initTerminalStyle(foreground = colorBrightGreen)

  var bindings = defaultPromptKeyBindings()
  bindings.submit.add keyBinding(keyText, "s", {modifierCtrl})

  let response = askText(initTextPromptOptions("Display name",
    presentation = defaultPresentation("Ctrl+S also submits", theme),
    runtime = defaultRuntimeOptions(output = stderr, keyBindings = bindings)))
  if response.isAnswered:
    echo "Hello, ", response.value
