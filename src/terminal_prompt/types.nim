## Public result, validation, option, and theme contracts.

import std/options

import terminal_style

type
  PromptError* = object of CatchableError
    ## Base error raised for prompt configuration or runtime failures.

  PromptConfigurationError* = object of PromptError
    ## Raised before interaction when prompt options are invalid.

  PromptIOError* = object of PromptError
    ## Raised when a configured input, output, or terminal backend fails.

  PromptStateError* = object of PromptError
    ## Raised when an internal prompt/session contract is used incorrectly.

  PromptNotImplementedError* = object of PromptError
    ## Raised by API contracts whose behavior belongs to a later milestone.

  PromptValueError* = object of PromptError
    ## Raised when the answer of a non-answered result is requested.

  PromptStatus* = enum
    ## The three normal outcomes shared by every prompt.
    promptAnswered
    promptCancelled
    promptEndOfInput

  PromptResult*[T] = object
    ## Result of one prompt interaction.
    ##
    ## ``promptCancelled`` represents an explicit user cancellation such as
    ## Escape or Ctrl+C. ``promptEndOfInput`` represents an exhausted input
    ## stream. Neither condition raises an exception.
    status*: PromptStatus
    answer: T

  Validator*[T] = proc(value: T): string {.closure.}
    ## Returns an empty string for a valid value, otherwise a user-facing error.

  PromptModifier* = enum
    ## Modifier keys usable in configurable prompt bindings.
    modifierShift
    modifierAlt
    modifierCtrl

  PromptKey* = enum
    ## Backend-neutral keys usable in configurable prompt bindings.
    keyUnknown
    keyText
    keySpace
    keyEnter
    keyEscape
    keyTab
    keyBacktab
    keyBackspace
    keyDelete
    keyInsert
    keyHome
    keyEnd
    keyArrowUp
    keyArrowDown
    keyArrowLeft
    keyArrowRight
    keyPageUp
    keyPageDown
    keyCtrlC
    keyCtrlD

  PromptKeyBinding* = object
    ## One key, optional text payload, and modifiers bound to an action.
    key*: PromptKey
    text*: string
    modifiers*: set[PromptModifier]

  PromptKeyBindings* = object
    ## Configurable keys for shared editing, navigation, and submission actions.
    submit*: seq[PromptKeyBinding]
    cancel*: seq[PromptKeyBinding]
    moveUp*: seq[PromptKeyBinding]
    moveDown*: seq[PromptKeyBinding]
    moveLeft*: seq[PromptKeyBinding]
    moveRight*: seq[PromptKeyBinding]
    moveFirst*: seq[PromptKeyBinding]
    moveLast*: seq[PromptKeyBinding]
    deleteBackward*: seq[PromptKeyBinding]
    deleteForward*: seq[PromptKeyBinding]
    toggle*: seq[PromptKeyBinding]

  PromptTheme* = object
    ## Semantic prompt roles represented directly as TerminalStyle values.
    question*: TerminalStyle
    answer*: TerminalStyle
    selection*: TerminalStyle
    error*: TerminalStyle
    hint*: TerminalStyle
    placeholder*: TerminalStyle

  PromptPresentation* = object
    ## Presentation shared by every prompt type.
    helpText*: string
    theme*: PromptTheme

  PromptRuntimeOptions* = object
    ## Streams and key bindings used to create an internal prompt session.
    input*: File
    output*: File
    keyBindings*: PromptKeyBindings

  TextPromptOptions* = object
    ## Options for a text prompt.
    message*: string
    defaultValue*: Option[string]
    placeholder*: string
    validator*: Validator[string]
    presentation*: PromptPresentation
    runtime*: PromptRuntimeOptions

  PasswordPromptOptions* = object
    ## Options for secret text input.
    message*: string
    mask*: string
    validator*: Validator[string]
    presentation*: PromptPresentation
    runtime*: PromptRuntimeOptions

  ConfirmPromptOptions* = object
    ## Options for a yes/no confirmation.
    message*: string
    defaultValue*: bool
    yesLabel*: string
    noLabel*: string
    presentation*: PromptPresentation
    runtime*: PromptRuntimeOptions

  PromptChoice*[T] = object
    ## One selectable value and its user-facing label.
    label*: string
    value*: T
    hint*: string
    disabled*: bool

  SelectPromptOptions*[T] = object
    ## Options for choosing exactly one value.
    message*: string
    choices*: seq[PromptChoice[T]]
    initialIndex*: Option[int]
    presentation*: PromptPresentation
    runtime*: PromptRuntimeOptions

  MultiSelectPromptOptions*[T] = object
    ## Options for choosing zero or more values.
    message*: string
    choices*: seq[PromptChoice[T]]
    initiallySelected*: seq[int]
    presentation*: PromptPresentation
    runtime*: PromptRuntimeOptions

proc answered*[T](value: sink T): PromptResult[T] =
  ## Constructs a successfully answered result.
  PromptResult[T](status: promptAnswered, answer: value)

proc cancelled*[T](): PromptResult[T] =
  ## Constructs an explicitly cancelled result.
  PromptResult[T](status: promptCancelled)

proc endOfInput*[T](): PromptResult[T] =
  ## Constructs a result for an exhausted input stream.
  PromptResult[T](status: promptEndOfInput)

proc isAnswered*[T](response: PromptResult[T]): bool =
  ## Returns whether ``response`` contains an answer.
  response.status == promptAnswered

proc isCancelled*[T](response: PromptResult[T]): bool =
  ## Returns whether the user explicitly cancelled the prompt.
  response.status == promptCancelled

proc isEndOfInput*[T](response: PromptResult[T]): bool =
  ## Returns whether the configured input stream ended.
  response.status == promptEndOfInput

proc value*[T](response: PromptResult[T]): T =
  ## Returns the answer or raises ``PromptValueError`` for other outcomes.
  if not response.isAnswered:
    raise newException(PromptValueError,
      "a prompt result only has a value when its status is promptAnswered")
  response.answer

proc valueOr*[T](response: PromptResult[T]; fallback: sink T): T =
  ## Returns the answer, or ``fallback`` for cancellation/end-of-input.
  if response.isAnswered: response.answer else: fallback

proc defaultPromptTheme*(): PromptTheme =
  ## Returns the semantic default theme backed by TerminalStyle.
  PromptTheme(
    question: initTerminalStyle(foreground = colorCyan,
      attributes = {taBold}),
    answer: initTerminalStyle(foreground = colorGreen),
    selection: initTerminalStyle(foreground = colorCyan,
      attributes = {taBold}),
    error: initTerminalStyle(foreground = colorRed),
    hint: initTerminalStyle(attributes = {taDim}),
    placeholder: initTerminalStyle(attributes = {taDim})
  )

proc keyBinding*(key: PromptKey; text = "";
                 modifiers: set[PromptModifier] = {}): PromptKeyBinding =
  ## Constructs one configurable key binding.
  PromptKeyBinding(key: key, text: text, modifiers: modifiers)

proc defaultPromptKeyBindings*(): PromptKeyBindings =
  ## Returns conventional prompt editing and navigation bindings.
  PromptKeyBindings(
    submit: @[keyBinding(keyEnter)],
    cancel: @[keyBinding(keyEscape), keyBinding(keyCtrlC)],
    moveUp: @[keyBinding(keyArrowUp)],
    moveDown: @[keyBinding(keyArrowDown)],
    moveLeft: @[keyBinding(keyArrowLeft)],
    moveRight: @[keyBinding(keyArrowRight)],
    moveFirst: @[keyBinding(keyHome)],
    moveLast: @[keyBinding(keyEnd)],
    deleteBackward: @[keyBinding(keyBackspace)],
    deleteForward: @[keyBinding(keyDelete)],
    toggle: @[keyBinding(keySpace)]
  )

proc defaultRuntimeOptions*(input: File = stdin; output: File = stdout;
                            keyBindings = defaultPromptKeyBindings()
                           ): PromptRuntimeOptions =
  ## Constructs runtime options, defaulting to the process streams.
  PromptRuntimeOptions(input: input, output: output, keyBindings: keyBindings)

proc defaultPresentation*(helpText = "";
                          theme = defaultPromptTheme()): PromptPresentation =
  ## Constructs presentation options shared by all prompt types.
  PromptPresentation(helpText: helpText, theme: theme)

proc initTextPromptOptions*(message: string;
                            defaultValue = none(string);
                            placeholder = "";
                            validator: Validator[string] = nil;
                            presentation = defaultPresentation();
                            runtime = defaultRuntimeOptions()
                           ): TextPromptOptions =
  ## Constructs text prompt options.
  TextPromptOptions(message: message, defaultValue: defaultValue,
    placeholder: placeholder, validator: validator,
    presentation: presentation, runtime: runtime)

proc initPasswordPromptOptions*(message: string; mask = "*";
                                validator: Validator[string] = nil;
                                presentation = defaultPresentation();
                                runtime = defaultRuntimeOptions()
                               ): PasswordPromptOptions =
  ## Constructs password prompt options. Secrets are never valid defaults.
  PasswordPromptOptions(message: message, mask: mask, validator: validator,
    presentation: presentation, runtime: runtime)

proc initConfirmPromptOptions*(message: string; defaultValue = false;
                               yesLabel = "Yes"; noLabel = "No";
                               presentation = defaultPresentation();
                               runtime = defaultRuntimeOptions()
                              ): ConfirmPromptOptions =
  ## Constructs confirmation prompt options.
  ConfirmPromptOptions(message: message, defaultValue: defaultValue,
    yesLabel: yesLabel, noLabel: noLabel, presentation: presentation,
    runtime: runtime)

proc choice*[T](label: string; value: sink T; hint = "";
                disabled = false): PromptChoice[T] =
  ## Constructs one selectable prompt choice.
  PromptChoice[T](label: label, value: value, hint: hint,
    disabled: disabled)

proc initSelectPromptOptions*[T](message: string;
                                 choices: sink seq[PromptChoice[T]];
                                 initialIndex = none(int);
                                 presentation = defaultPresentation();
                                 runtime = defaultRuntimeOptions()
                                ): SelectPromptOptions[T] =
  ## Constructs single-select prompt options.
  SelectPromptOptions[T](message: message, choices: choices,
    initialIndex: initialIndex, presentation: presentation, runtime: runtime)

proc initMultiSelectPromptOptions*[T](message: string;
                                      choices: sink seq[PromptChoice[T]];
                                      initiallySelected: sink seq[int] = @[];
                                      presentation = defaultPresentation();
                                      runtime = defaultRuntimeOptions()
                                     ): MultiSelectPromptOptions[T] =
  ## Constructs multi-select prompt options.
  MultiSelectPromptOptions[T](message: message, choices: choices,
    initiallySelected: initiallySelected, presentation: presentation,
    runtime: runtime)
