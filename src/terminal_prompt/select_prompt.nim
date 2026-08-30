## Single-selection prompt behavior.

import std/options

import ./[line_prompt, selection_prompt, session, types]

proc validateSelectOptions*[T](options: SelectPromptOptions[T]) =
  ## Validates single-selection configuration before interaction.
  validateSingleLine(options.message, "selection prompt message")
  validateSingleLine(options.presentation.helpText,
    "selection prompt help text")
  if options.choices.len == 0:
    raise newException(PromptConfigurationError,
      "single-select prompts require at least one choice")
  var enabled = 0
  for index, item in options.choices:
    validateSingleLine(item.label, "choice " & $(index + 1) & " label")
    validateSingleLine(item.hint, "choice " & $(index + 1) & " hint")
    if item.label.len == 0:
      raise newException(PromptConfigurationError,
        "choice labels cannot be empty")
    if not item.disabled:
      inc enabled
  if enabled == 0:
    raise newException(PromptConfigurationError,
      "single-select prompts require an enabled choice")
  if options.initialIndex.isSome:
    let index = options.initialIndex.get()
    if index < 0 or index >= options.choices.len:
      raise newException(PromptConfigurationError,
        "single-select initial index is outside the choice list")
    if options.choices[index].disabled:
      raise newException(PromptConfigurationError,
        "single-select initial choice cannot be disabled")

proc runSelectPrompt*[T](session: PromptSession;
                         options: SelectPromptOptions[T]): PromptResult[T] =
  ## Runs a single-select prompt against an injected session.
  try:
    options.validateSelectOptions()
  except CatchableError:
    if not session.isNil:
      session.close()
    raise

  var focus = if options.initialIndex.isSome: options.initialIndex.get() else: -1
  if focus < 0:
    for index, item in options.choices:
      if not item.disabled:
        focus = index
        break
  var selected = newSeq[bool](options.choices.len)
  let response = runSelectionPrompt(session, options.choices, focus, selected,
    SelectionPromptSpec(message: options.message,
      helpText: options.presentation.helpText,
      wrapNavigation: options.wrapNavigation,
      theme: options.presentation.theme,
      keyBindings: options.runtime.keyBindings))
  case response.status
  of promptAnswered:
    answered(options.choices[response.value[0]].value)
  of promptCancelled:
    cancelled[T]()
  of promptEndOfInput:
    endOfInput[T]()
