import std/unittest

import terminal_prompt/editor
import terminal_prompt/types

suite "shared line editor":
  test "initial values start with the cursor at the end":
    let empty = initLineEditor()
    check empty.isEmpty
    check empty.len == 0
    check empty.cursorPosition == 0
    check empty.cursorColumn == 0

    let editor = initLineEditor("prompt")
    check editor.value == "prompt"
    check editor.len == 6
    check editor.cursorPosition == 6
    check editor.cursorColumn == 6
    check editor.displayWidth == 6

  test "insertion, movement, and replacement preserve cursor invariants":
    var editor = initLineEditor("ac")
    check editor.moveLeft()
    check editor.insert("b")
    check editor.value == "abc"
    check editor.beforeCursor == "ab"
    check editor.afterCursor == "c"
    check editor.cursorPosition == 2

    check editor.moveFirst()
    check not editor.moveFirst()
    check editor.insert("0")
    check editor.value == "0abc"
    check editor.moveLast()
    check not editor.moveLast()

    editor.setValue("reset")
    check editor.value == "reset"
    check editor.cursorPosition == 5

  test "movement stops safely at both boundaries":
    var editor = initLineEditor("ab")
    check not editor.moveRight()
    check editor.moveLeft()
    check editor.moveLeft()
    check not editor.moveLeft()
    check editor.cursorPosition == 0
    check editor.moveRight()
    check editor.moveRight()
    check not editor.moveRight()

  test "cursor positions and columns are Unicode and cell aware":
    var editor = initLineEditor("a界🙂")
    check editor.len == 3
    check editor.displayWidth == 5
    check editor.cursorColumn == 5
    check editor.moveLeft()
    check editor.cursorPosition == 2
    check editor.cursorColumn == 3
    check editor.moveLeft()
    check editor.cursorColumn == 1

  test "combining marks and emoji sequences are single editable units":
    let combined = initLineEditor("e\u0301")
    check combined.len == 1
    check combined.cursorColumn == 1

    let family = initLineEditor("👩‍👩‍👧‍👦")
    check family.len == 1
    check family.cursorColumn == 2

    let flag = initLineEditor("🇳🇱")
    check flag.len == 1
    check flag.cursorColumn == 2

  test "insertion can merge with a neighboring grapheme":
    var editor = initLineEditor("e")
    check editor.insert("\u0301")
    check editor.value == "e\u0301"
    check editor.len == 1
    check editor.cursorPosition == 1
    check editor.cursorColumn == 1

  test "backspace and delete remove complete terminal graphemes":
    var editor = initLineEditor("a界e\u0301🙂")
    editor.setCursor(3)
    check editor.deleteBackward()
    check editor.value == "a界🙂"
    check editor.cursorPosition == 2
    check editor.deleteForward()
    check editor.value == "a界"
    check not editor.deleteForward()

    check editor.moveFirst()
    check not editor.deleteBackward()
    check editor.deleteForward()
    check editor.value == "界"

  test "empty insertion and deletion are no-ops":
    var editor = initLineEditor()
    check not editor.insert("")
    check not editor.deleteBackward()
    check not editor.deleteForward()

  test "invalid UTF-8 and control characters are rejected atomically":
    var editor = initLineEditor("safe")
    expect ValueError:
      discard editor.insert("line\nfeed")
    check editor.value == "safe"
    check editor.cursorPosition == 4

    expect ValueError:
      discard editor.insert("\x1b[31m")
    check editor.value == "safe"

    let invalid = "\xff"
    expect ValueError:
      discard editor.insert(invalid)
    check editor.value == "safe"

  test "explicit cursor positions are range checked":
    var editor = initLineEditor("ok")
    editor.setCursor(1)
    check editor.cursorPosition == 1
    expect PromptStateError:
      editor.setCursor(-1)
    expect PromptStateError:
      editor.setCursor(3)
