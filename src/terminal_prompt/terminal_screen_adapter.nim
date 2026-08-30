## Internal adapter from TerminalScreen to TerminalPrompt contracts.
##
## This module is intentionally not exported by the public
## ``terminal_prompt`` facade.

import std/options

import terminal_screen as screen

import ./[keys, session, types]

type
  TerminalScreenPromptSession* = ref object of PromptSession
    ## Active TerminalScreen session adapted to prompt-owned contracts.
    backend: screen.TerminalSession
    output: File
    selectedMode: PromptSessionMode

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

proc openTerminalScreenSession*(input: File = stdin; output: File = stdout;
                                options = defaultPromptSessionOptions()
                               ): PromptSession =
  ## Opens TerminalScreen and selects an interactive or line-mode strategy.
  try:
    let detected = detectPromptCapabilities(input, output, options.ansiMode)
    let selectedMode = detected.selectSessionMode(options)
    var effectiveOptions = options
    if selectedMode == promptLineMode:
      effectiveOptions.rawMode = false
      effectiveOptions.hideCursor = false
      effectiveOptions.monitorResize = false
      effectiveOptions.ansiMode = promptAnsiNever
    TerminalScreenPromptSession(
      backend: screen.openSession(input, output,
        effectiveOptions.toScreenOptions()),
      output: output,
      selectedMode: selectedMode
    )
  except screen.TerminalError as error:
    raise newException(PromptIOError,
      "cannot open TerminalScreen prompt session: " & error.msg, error)

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
