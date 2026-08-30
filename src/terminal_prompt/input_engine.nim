## Binding-aware consumption of backend-neutral prompt input events.

import std/options

import ./[io, keys, types]

type
  PromptAction* = enum
    ## Logical actions shared by prompt state machines.
    actionSubmit
    actionCancel
    actionMoveUp
    actionMoveDown
    actionMoveLeft
    actionMoveRight
    actionMoveFirst
    actionMoveLast
    actionDeleteBackward
    actionDeleteForward
    actionToggle
    actionSelectAll
    actionClearSelection

  PromptEngineEventKind* = enum
    ## Events emitted by ``PromptInputEngine``.
    engineAction
    engineKey
    engineResize
    engineEndOfInput
    engineTimeout

  PromptEngineEvent* = object
    ## One input event resolved against the configured key bindings.
    case kind*: PromptEngineEventKind
    of engineAction:
      action*: PromptAction
      actionKey*: PromptKeyEvent
    of engineKey:
      key*: PromptKeyEvent
    of engineResize:
      size*: PromptSize
    of engineEndOfInput, engineTimeout:
      discard

  PromptInputEngine* = ref object
    ## Reads normalized input and resolves configured prompt actions.
    io: PromptIO
    bindings: PromptKeyBindings

proc matches*(event: PromptKeyEvent; binding: PromptKeyBinding): bool =
  ## Returns whether a normalized key event exactly matches a binding.
  binding.key == event.key and binding.text == event.text and
    binding.modifiers == event.modifiers

proc contains(bindings: openArray[PromptKeyBinding];
              event: PromptKeyEvent): bool =
  for binding in bindings:
    if event.matches(binding):
      return true

proc resolveAction*(event: PromptKeyEvent;
                    bindings: PromptKeyBindings): Option[PromptAction] =
  ## Resolves a key using deterministic action precedence.
  ##
  ## Cancellation is checked first so a custom binding cannot accidentally be
  ## shadowed by a less urgent action.
  if bindings.cancel.contains(event): some(actionCancel)
  elif bindings.submit.contains(event): some(actionSubmit)
  elif bindings.moveUp.contains(event): some(actionMoveUp)
  elif bindings.moveDown.contains(event): some(actionMoveDown)
  elif bindings.moveLeft.contains(event): some(actionMoveLeft)
  elif bindings.moveRight.contains(event): some(actionMoveRight)
  elif bindings.moveFirst.contains(event): some(actionMoveFirst)
  elif bindings.moveLast.contains(event): some(actionMoveLast)
  elif bindings.deleteBackward.contains(event): some(actionDeleteBackward)
  elif bindings.deleteForward.contains(event): some(actionDeleteForward)
  elif bindings.toggle.contains(event): some(actionToggle)
  elif bindings.selectAll.contains(event): some(actionSelectAll)
  elif bindings.clearSelection.contains(event): some(actionClearSelection)
  else: none(PromptAction)

proc newPromptInputEngine*(io: PromptIO;
                           bindings = defaultPromptKeyBindings()
                          ): PromptInputEngine =
  ## Creates a binding-aware input engine over injected I/O.
  if io.isNil:
    raise newException(PromptStateError, "prompt input cannot be nil")
  PromptInputEngine(io: io, bindings: bindings)

proc readInput*(engine: PromptInputEngine;
                timeoutMs = -1): PromptEngineEvent =
  ## Reads one normalized event and resolves key bindings without losing data.
  if engine.isNil or engine.io.isNil:
    raise newException(PromptStateError, "prompt input engine is not initialized")
  let event = engine.io.readEvent(timeoutMs)
  case event.kind
  of inputKey:
    let action = event.keyEvent.resolveAction(engine.bindings)
    if action.isSome:
      PromptEngineEvent(kind: engineAction, action: action.get(),
        actionKey: event.keyEvent)
    else:
      PromptEngineEvent(kind: engineKey, key: event.keyEvent)
  of inputResize:
    PromptEngineEvent(kind: engineResize, size: event.size)
  of inputEndOfInput:
    PromptEngineEvent(kind: engineEndOfInput)
  of inputTimeout:
    PromptEngineEvent(kind: engineTimeout)
