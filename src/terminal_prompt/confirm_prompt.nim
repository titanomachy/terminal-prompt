## Configurable yes/no confirmation prompt behavior.

import std/[strutils, unicode]

import ./[editor, line_prompt, session, types]

proc normalized(value: string): string =
  unicode.toLower(strutils.strip(value))

proc firstUnit(value: string): string =
  let editor = initLineEditor(value)
  if editor.isEmpty:
    return ""
  var first = editor
  first.setCursor(1)
  first.beforeCursor

proc validateConfirmOptions*(options: ConfirmPromptOptions) =
  validateSingleLine(options.message, "confirmation prompt message")
  validateSingleLine(options.yesLabel, "confirmation yes label")
  validateSingleLine(options.noLabel, "confirmation no label")
  validateSingleLine(options.presentation.helpText,
    "confirmation prompt help text")
  if options.yesLabel.len == 0 or options.noLabel.len == 0:
    raise newException(PromptConfigurationError,
      "confirmation labels cannot be empty")
  if options.yesLabel.normalized == options.noLabel.normalized:
    raise newException(PromptConfigurationError,
      "confirmation labels must be distinct")

proc runConfirmPrompt*(session: PromptSession;
                       options: ConfirmPromptOptions): PromptResult[bool] =
  ## Runs a confirmation prompt with configurable labels and default.
  try:
    options.validateConfirmOptions()
  except CatchableError:
    if not session.isNil:
      session.close()
    raise
  let
    defaultLabel = if options.defaultValue: options.yesLabel else: options.noLabel
    hint = "[" & options.yesLabel & "/" & options.noLabel &
      ", default: " & defaultLabel & "]"
    yes = options.yesLabel.normalized
    no = options.noLabel.normalized
    yesShort = options.yesLabel.firstUnit.normalized
    noShort = options.noLabel.firstUnit.normalized
    allowShort = yesShort != noShort
  let spec = LinePromptSpec(
    message: options.message,
    hint: hint,
    helpText: options.presentation.helpText,
    theme: options.presentation.theme,
    keyBindings: options.runtime.keyBindings
  )
  let submitter: LineSubmitter = proc(value: string): LineSubmission =
    let candidate = value.normalized
    if candidate.len == 0:
      return acceptLine(defaultLabel)
    if candidate == yes or (allowShort and candidate == yesShort):
      return acceptLine(options.yesLabel)
    if candidate == no or (allowShort and candidate == noShort):
      return acceptLine(options.noLabel)
    retryLine("Enter " & options.yesLabel & " or " & options.noLabel & ".")

  let response = runLinePrompt(session, spec, submitter)
  case response.status
  of promptAnswered:
    answered(response.value.normalized == yes)
  of promptCancelled:
    cancelled[bool]()
  of promptEndOfInput:
    endOfInput[bool]()
