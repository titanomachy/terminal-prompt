## Synchronous, one-shot terminal prompts.
##
## Text, password, confirmation, single-select, and multi-select prompts are
## implemented with interactive and redirected-stream behavior. Applications
## normally need only this facade; options constructors expose validation,
## themes, custom streams, key bindings, typed choices, and defaults.
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
##
## Password values are masked during entry and redacted from ``$`` output, but
## callers must still treat an answered result's ``value`` as sensitive.

import terminal_prompt/[api, types]

export api, types
