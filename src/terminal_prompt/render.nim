## Backend-neutral renderer contract and semantic TerminalStyle renderer.

import terminal_style

import ./types

type
  PromptRole* = enum
    rolePlain
    roleQuestion
    roleAnswer
    roleSelection
    roleError
    roleHint
    rolePlaceholder

  PromptSegment* = object
    ## A piece of text tagged with a semantic theme role.
    role*: PromptRole
    text*: string

  PromptFrame* = object
    ## Ordered render segments for one prompt redraw.
    segments*: seq[PromptSegment]

  PromptRenderer* = ref object of RootObj
    ## Converts prompt state into output without reading or writing streams.

  SemanticRenderer* = ref object of PromptRenderer
    ## Default renderer that maps every semantic role to ``PromptTheme``.

proc segment*(role: PromptRole; text: sink string): PromptSegment =
  ## Constructs one semantic render segment.
  PromptSegment(role: role, text: text)

proc frame*(segments: sink seq[PromptSegment]): PromptFrame =
  ## Constructs one render frame.
  PromptFrame(segments: segments)

proc styleFor(theme: PromptTheme; role: PromptRole): TerminalStyle =
  case role
  of rolePlain: initTerminalStyle()
  of roleQuestion: theme.question
  of roleAnswer: theme.answer
  of roleSelection: theme.selection
  of roleError: theme.error
  of roleHint: theme.hint
  of rolePlaceholder: theme.placeholder

method render*(renderer: PromptRenderer; frame: PromptFrame;
               theme: PromptTheme; ansi: bool): string {.base.} =
  ## Renders one frame. Implementations must be deterministic and side-effect-free.
  raise newException(PromptStateError,
    "render is not implemented by this PromptRenderer")

method render*(renderer: SemanticRenderer; frame: PromptFrame;
               theme: PromptTheme; ansi: bool): string =
  ## Applies TerminalStyle by semantic role, or returns plain text without ANSI.
  for item in frame.segments:
    if item.role == rolePlain:
      result.add item.text
    else:
      result.add applyStyle(item.text, theme.styleFor(item.role), ansi)

proc newSemanticRenderer*(): PromptRenderer =
  ## Creates the default semantic renderer behind its renderer interface.
  SemanticRenderer()
