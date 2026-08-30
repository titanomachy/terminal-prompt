## Synchronous, one-shot terminal prompt contracts.
##
## TerminalPrompt exposes the Milestone 0 API contracts and uses the Milestone
## 1 safe session/input foundation internally. Concrete prompt editors are
## added in subsequent milestones; calling an ``ask*`` proc until then raises
## ``PromptNotImplementedError``.
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
