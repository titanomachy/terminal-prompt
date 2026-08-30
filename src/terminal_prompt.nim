## Synchronous, one-shot terminal prompts.
##
## Text, password, confirmation, single-select, and multi-select prompts are
## implemented with interactive and redirected-stream behavior.
##
## Cancellation and end-of-input are values, not exceptions:
##
## .. code-block:: nim
##
##   import terminal_prompt
##
##   let result = askText("Project name", default = "my-project")
##   case result.status
##   of promptAnswered:
##     echo result.value
##   of promptCancelled:
##     echo "cancelled"
##   of promptEndOfInput:
##     echo "input closed"

import terminal_prompt/[api, types]

export api, types
