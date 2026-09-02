## Internal adapter from TerminalScreen to TerminalPrompt contracts.
##
## This module is intentionally not exported by the public
## ``terminal_prompt`` facade.

import std/options

import terminal_screen as screen

import ./[keys, session, types]

type
  TerminalScreenSessionOpener* = proc(input, output: File;
      options: screen.SessionOptions): screen.TerminalSession
    ## Injectable TerminalScreen opener used to test setup fallback behavior.

  TerminalScreenPromptSession* = ref object of PromptSession
    ## Active TerminalScreen session adapted to prompt-owned contracts.
    backend: screen.TerminalSession
    output: File
    selectedMode: PromptSessionMode

  LinePromptSession = ref object of PromptSession
    ## Line-oriented session that does not read ahead across prompt calls.
    input: File
    output: File
    detectedCapabilities: PromptCapabilities
    pendingEnter: bool
    inputEnded: bool
    closed: bool

proc toPromptModifiers(modifiers: set[screen.Modifier]):
    set[PromptModifier] =
  if screen.modifierShift in modifiers:
    result.incl modifierShift
  if screen.modifierAlt in modifiers:
    result.incl modifierAlt
  if screen.modifierCtrl in modifiers:
    result.incl modifierCtrl

proc toPromptKey(key: screen.Key): PromptKey =
  case key
  of screen.keyUnknown: keyUnknown
  of screen.keyText: keyText
  of screen.keySpace: keySpace
  of screen.keyEnter: keyEnter
  of screen.keyEscape: keyEscape
  of screen.keyTab: keyTab
  of screen.keyBacktab: keyBacktab
  of screen.keyBackspace: keyBackspace
  of screen.keyDelete: keyDelete
  of screen.keyInsert: keyInsert
  of screen.keyHome: keyHome
  of screen.keyEnd: keyEnd
  of screen.keyArrowUp: keyArrowUp
  of screen.keyArrowDown: keyArrowDown
  of screen.keyArrowLeft: keyArrowLeft
  of screen.keyArrowRight: keyArrowRight
  of screen.keyPageUp: keyPageUp
  of screen.keyPageDown: keyPageDown
  of screen.keyCtrlC: keyCtrlC
  of screen.keyCtrlD: keyCtrlD

proc toPromptEvent*(event: screen.InputEvent): PromptInputEvent =
  ## Converts a TerminalScreen event without leaking its types to prompt engines.
  case event.kind
  of screen.eventKey:
    keyInput(toPromptKey(event.keyEvent.key), event.keyEvent.text,
      toPromptModifiers(event.keyEvent.modifiers), event.keyEvent.sequence)
  of screen.eventResize:
    resizeInput(event.size.columns, event.size.rows)
  of screen.eventEndOfInput:
    endInput()
  of screen.eventTimeout:
    PromptInputEvent(kind: inputTimeout)

proc toScreenOptions(options: PromptSessionOptions): screen.SessionOptions =
  result = screen.defaultSessionOptions()
  result.rawMode = options.rawMode
  result.hideCursor = options.hideCursor
  result.requireTerminal = options.requireTerminal
  result.monitorResize = options.monitorResize
  result.ansiMode = (case options.ansiMode
    of promptAnsiAuto: screen.ansiAuto
    of promptAnsiAlways: screen.ansiAlways
    of promptAnsiNever: screen.ansiNever)
  result.escapeTimeoutMs = options.escapeTimeoutMs
  result.resizePollMs = options.resizePollMs

proc detectPromptCapabilities(input, output: File;
                              ansiMode: PromptAnsiMode): PromptCapabilities =
  let value = screen.detectCapabilities(input, output, (case ansiMode
    of promptAnsiAuto: screen.ansiAuto
    of promptAnsiAlways: screen.ansiAlways
    of promptAnsiNever: screen.ansiNever))
  PromptCapabilities(
    inputIsTerminal: value.inputIsTerminal,
    outputIsTerminal: value.outputIsTerminal,
    supportsAnsi: value.supportsAnsi,
    supportsRawMode: value.supportsRawMode,
    supportsResizeEvents: value.supportsResizeEvents
  )

proc openLinePromptSession(input, output: File;
                           detected: PromptCapabilities): PromptSession =
  var lineCapabilities = detected
  lineCapabilities.supportsAnsi = false
  lineCapabilities.supportsRawMode = false
  lineCapabilities.supportsResizeEvents = false
  LinePromptSession(input: input, output: output,
    detectedCapabilities: lineCapabilities)

proc openTerminalScreenSessionWithCapabilities*(
    input, output: File;
    options: PromptSessionOptions;
    detected: PromptCapabilities;
    openInteractive: TerminalScreenSessionOpener): PromptSession =
  ## Selects and opens a prompt strategy from already detected capabilities.
  ##
  ## This internal seam keeps interactive setup failures deterministic in tests.
  let selectedMode = detected.selectSessionMode(options)
  if options.requireTerminal and
      (not detected.inputIsTerminal or not detected.outputIsTerminal):
    raise newException(PromptIOError,
      "cannot open prompt session: input and output must be terminals")
  if selectedMode == promptLineMode:
    return openLinePromptSession(input, output, detected)

  try:
    TerminalScreenPromptSession(
      backend: openInteractive(input, output,
        options.toScreenOptions()),
      output: output,
      selectedMode: selectedMode
    )
  except screen.TerminalError as error:
    if options.requireTerminal:
      raise newException(PromptIOError,
        "cannot open TerminalScreen prompt session: " & error.msg, error)
    openLinePromptSession(input, output, detected)

proc openTerminalScreenSession*(input: File = stdin; output: File = stdout;
                                options = defaultPromptSessionOptions()
                               ): PromptSession =
  ## Opens TerminalScreen and selects an interactive or line-mode strategy.
  try:
    let detected = detectPromptCapabilities(input, output, options.ansiMode)
    openTerminalScreenSessionWithCapabilities(input, output, options, detected,
      screen.openSession)
  except screen.TerminalError as error:
    raise newException(PromptIOError,
      "cannot detect TerminalScreen prompt capabilities: " & error.msg, error)

method readEvent*(session: LinePromptSession;
                  timeoutMs = -1): PromptInputEvent =
  if session.closed:
    raise newException(PromptStateError,
      "cannot read from a closed line prompt session")
  if session.pendingEnter:
    session.pendingEnter = false
    return keys.keyInput(types.keyEnter)
  if session.inputEnded:
    return keys.endInput()
  try:
    var line: string
    if not session.input.readLine(line):
      session.inputEnded = true
      return keys.endInput()
    if line.len == 0:
      return keys.keyInput(types.keyEnter)
    session.pendingEnter = true
    keys.keyInput(types.keyText, text = line, sequence = line)
  except IOError as error:
    raise newException(PromptIOError,
      "cannot read line prompt input: " & error.msg, error)

method write*(session: LinePromptSession; value: string) =
  if session.closed:
    raise newException(PromptStateError,
      "cannot write to a closed line prompt session")
  try:
    session.output.write(value)
  except IOError as error:
    raise newException(PromptIOError,
      "cannot write prompt output: " & error.msg, error)

method flush*(session: LinePromptSession) =
  if session.closed:
    raise newException(PromptStateError,
      "cannot flush a closed line prompt session")
  try:
    session.output.flushFile()
  except IOError as error:
    raise newException(PromptIOError,
      "cannot flush prompt output: " & error.msg, error)

method capabilities*(session: LinePromptSession): PromptCapabilities =
  session.detectedCapabilities

method mode*(session: LinePromptSession): PromptSessionMode =
  promptLineMode

method terminalSize*(session: LinePromptSession): Option[PromptSize] =
  none(PromptSize)

method close*(session: LinePromptSession) =
  session.closed = true

method readEvent*(session: TerminalScreenPromptSession;
                  timeoutMs = -1): PromptInputEvent =
  try:
    session.backend.readEvent(timeoutMs).toPromptEvent()
  except screen.TerminalError as error:
    raise newException(PromptIOError,
      "cannot read TerminalScreen prompt event: " & error.msg, error)

method write*(session: TerminalScreenPromptSession; value: string) =
  try:
    session.output.write(value)
  except IOError as error:
    raise newException(PromptIOError,
      "cannot write prompt output: " & error.msg, error)

method flush*(session: TerminalScreenPromptSession) =
  try:
    session.output.flushFile()
  except IOError as error:
    raise newException(PromptIOError,
      "cannot flush prompt output: " & error.msg, error)

method capabilities*(session: TerminalScreenPromptSession):
    PromptCapabilities =
  let value = session.backend.capabilities()
  PromptCapabilities(
    inputIsTerminal: value.inputIsTerminal,
    outputIsTerminal: value.outputIsTerminal,
    supportsAnsi: value.supportsAnsi,
    supportsRawMode: value.supportsRawMode,
    supportsResizeEvents: value.supportsResizeEvents
  )

method mode*(session: TerminalScreenPromptSession): PromptSessionMode =
  session.selectedMode

method terminalSize*(session: TerminalScreenPromptSession):
    Option[PromptSize] =
  let value = session.output.tryTerminalSize()
  if value.isNone:
    return none(PromptSize)
  some(PromptSize(columns: value.get().columns, rows: value.get().rows))

method close*(session: TerminalScreenPromptSession) =
  try:
    session.backend.close()
  except screen.TerminalError as error:
    raise newException(PromptIOError,
      "cannot close TerminalScreen prompt session: " & error.msg, error)
