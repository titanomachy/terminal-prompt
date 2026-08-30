## Text prompt behavior built on the shared editable-line state machine.

import std/options

import ./[line_prompt, session, types]

proc validateTextOptions*(options: TextPromptOptions) =
  validateSingleLine(options.message, "text prompt message")
  validateSingleLine(options.placeholder, "text prompt placeholder")
  validateSingleLine(options.presentation.helpText, "text prompt help text")
  if options.defaultValue.isSome:
    validateSingleLine(options.defaultValue.get(), "text prompt default")

proc runTextPrompt*(session: PromptSession;
                    options: TextPromptOptions): PromptResult[string] =
  ## Runs a text prompt against an injected session and closes the session.
  try:
    options.validateTextOptions()
  except CatchableError:
    if not session.isNil:
      session.close()
    raise
  let placeholder = if options.defaultValue.isSome:
      options.defaultValue.get()
    else:
      options.placeholder
  let spec = LinePromptSpec(
    message: options.message,
    helpText: options.presentation.helpText,
    placeholder: placeholder,
    theme: options.presentation.theme,
    keyBindings: options.runtime.keyBindings
  )
  let submitter: LineSubmitter = proc(value: string): LineSubmission =
    let candidate = if value.len == 0 and options.defaultValue.isSome:
        options.defaultValue.get()
      else:
        value
    if not options.validator.isNil:
      let error = options.validator(candidate)
      if error.len > 0:
        return retryLine(error)
    acceptLine(candidate)
  runLinePrompt(session, spec, submitter)
