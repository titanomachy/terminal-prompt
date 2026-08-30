## Multiple-selection prompt behavior.

import std/sets

import ./[line_prompt, selection_prompt, session, types]

proc validateMultiSelectOptions*[T](options: MultiSelectPromptOptions[T]) =
  ## Validates multiple-selection configuration before interaction.
  validateSingleLine(options.message, "multi-select prompt message")
  validateSingleLine(options.presentation.helpText,
    "multi-select prompt help text")
  for index, item in options.choices:
    validateSingleLine(item.label, "choice " & $(index + 1) & " label")
    validateSingleLine(item.hint, "choice " & $(index + 1) & " hint")
    if item.label.len == 0:
      raise newException(PromptConfigurationError,
        "choice labels cannot be empty")
  var seen = initHashSet[int]()
  for index in options.initiallySelected:
    if index < 0 or index >= options.choices.len:
      raise newException(PromptConfigurationError,
        "multi-select initial index is outside the choice list")
    if options.choices[index].disabled:
      raise newException(PromptConfigurationError,
        "disabled choices cannot be initially selected")
    if index in seen:
      raise newException(PromptConfigurationError,
        "multi-select initial indices must be unique")
    seen.incl index

proc runMultiSelectPrompt*[T](session: PromptSession;
                              options: MultiSelectPromptOptions[T]):
    PromptResult[seq[T]] =
  ## Runs a multi-select prompt against an injected session.
  try:
    options.validateMultiSelectOptions()
  except CatchableError:
    if not session.isNil:
      session.close()
    raise

  var
    selected = newSeq[bool](options.choices.len)
    focus = -1
  for index in options.initiallySelected:
    selected[index] = true
    if focus < 0:
      focus = index
  if focus < 0:
    for index, item in options.choices:
      if not item.disabled:
        focus = index
        break

  let response = runSelectionPrompt(session, options.choices, focus, selected,
    SelectionPromptSpec(message: options.message,
      helpText: options.presentation.helpText,
      multiple: true,
      wrapNavigation: options.wrapNavigation,
      theme: options.presentation.theme,
      keyBindings: options.runtime.keyBindings))
  case response.status
  of promptAnswered:
    var values: seq[T]
    for index in response.value:
      values.add options.choices[index].value
    answered(values)
  of promptCancelled:
    cancelled[seq[T]]()
  of promptEndOfInput:
    endOfInput[seq[T]]()
