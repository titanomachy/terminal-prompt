## Public synchronous prompt API.

import std/options

import ./[confirm_prompt, password_prompt, terminal_screen_adapter,
  text_prompt, types]

proc pending[T](name: string): PromptResult[T] =
  raise newException(PromptNotImplementedError,
    name & " behavior is planned for a later TerminalPrompt milestone")

proc askText*(options: TextPromptOptions): PromptResult[string] =
  ## Runs a text prompt using explicit options.
  options.validateTextOptions()
  runTextPrompt(openTerminalScreenSession(options.runtime.input,
    options.runtime.output), options)

proc askText*(message: string; placeholder = ""; helpText = "";
              validator: Validator[string] = nil;
              theme = defaultPromptTheme()): PromptResult[string] =
  ## Runs a text prompt without a default value.
  askText(initTextPromptOptions(message, placeholder = placeholder,
    validator = validator,
    presentation = defaultPresentation(helpText, theme)))

proc askText*(message: string; default: string; placeholder = "";
              helpText = ""; validator: Validator[string] = nil;
              theme = defaultPromptTheme()): PromptResult[string] =
  ## Runs a text prompt with a default value.
  askText(initTextPromptOptions(message, some(default), placeholder,
    validator, defaultPresentation(helpText, theme)))

proc askPassword*(options: PasswordPromptOptions): PromptResult[string] =
  ## Runs a secret text prompt using explicit options.
  options.validatePasswordOptions()
  runPasswordPrompt(openTerminalScreenSession(options.runtime.input,
    options.runtime.output), options)

proc askPassword*(message: string; mask = "*"; helpText = "";
                  validator: Validator[string] = nil;
                  theme = defaultPromptTheme()): PromptResult[string] =
  ## Runs a password prompt. Passwords do not support default values.
  askPassword(initPasswordPromptOptions(message, mask, validator,
    defaultPresentation(helpText, theme)))

proc askConfirm*(options: ConfirmPromptOptions): PromptResult[bool] =
  ## Runs a confirmation prompt using explicit options.
  options.validateConfirmOptions()
  runConfirmPrompt(openTerminalScreenSession(options.runtime.input,
    options.runtime.output), options)

proc askConfirm*(message: string; default = false; yesLabel = "Yes";
                 noLabel = "No"; helpText = "";
                 theme = defaultPromptTheme()): PromptResult[bool] =
  ## Runs a yes/no confirmation prompt.
  askConfirm(initConfirmPromptOptions(message, default, yesLabel, noLabel,
    defaultPresentation(helpText, theme)))

proc askSelect*[T](options: SelectPromptOptions[T]): PromptResult[T] =
  ## Runs a single-select prompt using explicit options.
  pending[T]("askSelect")

proc askSelect*(message: string; choices: openArray[string];
                helpText = "";
                theme = defaultPromptTheme()): PromptResult[string] =
  ## Runs a single-select prompt over string choices.
  var values: seq[PromptChoice[string]]
  for value in choices:
    values.add choice(value, value)
  askSelect(initSelectPromptOptions(message, values,
    presentation = defaultPresentation(helpText, theme)))

proc askMultiSelect*[T](options: MultiSelectPromptOptions[T]):
    PromptResult[seq[T]] =
  ## Runs a multi-select prompt using explicit options.
  pending[seq[T]]("askMultiSelect")

proc askMultiSelect*(message: string; choices: openArray[string];
                     helpText = "";
                     theme = defaultPromptTheme()
                    ): PromptResult[seq[string]] =
  ## Runs a multi-select prompt over string choices.
  var values: seq[PromptChoice[string]]
  for value in choices:
    values.add choice(value, value)
  askMultiSelect(initMultiSelectPromptOptions(message, values,
    presentation = defaultPresentation(helpText, theme)))
