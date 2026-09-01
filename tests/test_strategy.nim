import std/unittest

import terminal_prompt
import terminal_prompt/[confirm_prompt, keys, multiselect_prompt,
  password_prompt, select_prompt, session, text_prompt, types]

import ./support/scripted_session

proc enter(): PromptInputEvent =
  keyInput(keyEnter)

proc cancel(): PromptInputEvent =
  keyInput(keyEscape)

template checkClosedOnce(scripted: ScriptedSession) =
  check scripted.closed
  check scripted.closeCount == 1

suite "test-strategy exit-path matrix":
  test "every prompt closes its session after success":
    let textSession = newScriptedSession(@[enter()])
    check runTextPrompt(PromptSession(textSession),
      initTextPromptOptions("Text")).isAnswered
    checkClosedOnce(textSession)

    let passwordSession = newScriptedSession(@[enter()])
    check runPasswordPrompt(PromptSession(passwordSession),
      initPasswordPromptOptions("Password")).isAnswered
    checkClosedOnce(passwordSession)

    let confirmSession = newScriptedSession(@[enter()])
    check runConfirmPrompt(PromptSession(confirmSession),
      initConfirmPromptOptions("Confirm")).isAnswered
    checkClosedOnce(confirmSession)

    let selectSession = newScriptedSession(@[enter()])
    check runSelectPrompt(PromptSession(selectSession),
      initSelectPromptOptions("Select", @[choice("One", 1)])).isAnswered
    checkClosedOnce(selectSession)

    let multiSession = newScriptedSession(@[enter()])
    check runMultiSelectPrompt(PromptSession(multiSession),
      initMultiSelectPromptOptions("Select", @[choice("One", 1)])).isAnswered
    checkClosedOnce(multiSession)

  test "every prompt closes its session after cancellation":
    let textSession = newScriptedSession(@[cancel()])
    check runTextPrompt(PromptSession(textSession),
      initTextPromptOptions("Text")).isCancelled
    checkClosedOnce(textSession)

    let passwordSession = newScriptedSession(@[cancel()])
    check runPasswordPrompt(PromptSession(passwordSession),
      initPasswordPromptOptions("Password")).isCancelled
    checkClosedOnce(passwordSession)

    let confirmSession = newScriptedSession(@[cancel()])
    check runConfirmPrompt(PromptSession(confirmSession),
      initConfirmPromptOptions("Confirm")).isCancelled
    checkClosedOnce(confirmSession)

    let selectSession = newScriptedSession(@[cancel()])
    check runSelectPrompt(PromptSession(selectSession),
      initSelectPromptOptions("Select", @[choice("One", 1)])).isCancelled
    checkClosedOnce(selectSession)

    let multiSession = newScriptedSession(@[cancel()])
    check runMultiSelectPrompt(PromptSession(multiSession),
      initMultiSelectPromptOptions("Select", @[choice("One", 1)])).isCancelled
    checkClosedOnce(multiSession)

  test "every prompt closes its session after EOF":
    let textSession = newScriptedSession(@[endInput()])
    check runTextPrompt(PromptSession(textSession),
      initTextPromptOptions("Text")).isEndOfInput
    checkClosedOnce(textSession)

    let passwordSession = newScriptedSession(@[endInput()])
    check runPasswordPrompt(PromptSession(passwordSession),
      initPasswordPromptOptions("Password")).isEndOfInput
    checkClosedOnce(passwordSession)

    let confirmSession = newScriptedSession(@[endInput()])
    check runConfirmPrompt(PromptSession(confirmSession),
      initConfirmPromptOptions("Confirm")).isEndOfInput
    checkClosedOnce(confirmSession)

    let selectSession = newScriptedSession(@[endInput()])
    check runSelectPrompt(PromptSession(selectSession),
      initSelectPromptOptions("Select", @[choice("One", 1)])).isEndOfInput
    checkClosedOnce(selectSession)

    let multiSession = newScriptedSession(@[endInput()])
    check runMultiSelectPrompt(PromptSession(multiSession),
      initMultiSelectPromptOptions("Select", @[choice("One", 1)])).isEndOfInput
    checkClosedOnce(multiSession)

  test "every prompt closes its session after an I/O exception":
    let textSession = newScriptedSession()
    textSession.failRead = true
    expect PromptIOError:
      discard runTextPrompt(PromptSession(textSession),
        initTextPromptOptions("Text"))
    checkClosedOnce(textSession)

    let passwordSession = newScriptedSession()
    passwordSession.failRead = true
    expect PromptIOError:
      discard runPasswordPrompt(PromptSession(passwordSession),
        initPasswordPromptOptions("Password"))
    checkClosedOnce(passwordSession)

    let confirmSession = newScriptedSession()
    confirmSession.failRead = true
    expect PromptIOError:
      discard runConfirmPrompt(PromptSession(confirmSession),
        initConfirmPromptOptions("Confirm"))
    checkClosedOnce(confirmSession)

    let selectSession = newScriptedSession()
    selectSession.failRead = true
    expect PromptIOError:
      discard runSelectPrompt(PromptSession(selectSession),
        initSelectPromptOptions("Select", @[choice("One", 1)]))
    checkClosedOnce(selectSession)

    let multiSession = newScriptedSession()
    multiSession.failRead = true
    expect PromptIOError:
      discard runMultiSelectPrompt(PromptSession(multiSession),
        initMultiSelectPromptOptions("Select", @[choice("One", 1)]))
    checkClosedOnce(multiSession)
