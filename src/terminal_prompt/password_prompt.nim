## Password prompt behavior with output and diagnostic redaction.

import std/strutils

import ./[editor, line_prompt, session, types]

proc validatePasswordOptions*(options: PasswordPromptOptions) =
  validateSingleLine(options.message, "password prompt message")
  validateSingleLine(options.mask, "password prompt mask")
  validateSingleLine(options.presentation.helpText,
    "password prompt help text")
  if initLineEditor(options.mask).len > 1:
    raise newException(PromptConfigurationError,
      "password prompt mask must contain at most one terminal grapheme")

proc redactedValidationError(error, secret: string): string =
  if secret.len > 0 and secret in error:
    error.replace(secret, "[redacted]")
  else:
    error

proc runPasswordPrompt*(session: PromptSession;
                        options: PasswordPromptOptions): PromptResult[string] =
  ## Runs a password prompt without rendering the submitted secret.
  try:
    options.validatePasswordOptions()
  except CatchableError:
    if not session.isNil:
      session.close()
    raise
  let spec = LinePromptSpec(
    message: options.message,
    helpText: options.presentation.helpText,
    mask: options.mask,
    secret: true,
    theme: options.presentation.theme,
    keyBindings: options.runtime.keyBindings
  )
  let submitter: LineSubmitter = proc(value: string): LineSubmission =
    if not options.validator.isNil:
      var error: string
      try:
        error = options.validator(value)
      except CatchableError:
        raise newException(PromptError,
          "password validator failed without exposing its input")
      if error.len > 0:
        return retryLine(error.redactedValidationError(value))
    acceptLine(value)
  runLinePrompt(session, spec, submitter)
