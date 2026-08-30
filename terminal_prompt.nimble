# Package

version       = "0.1.0"
author        = "titanomachy"
description   = "Pure-Nim terminal input boxes, password masking, single-select, multi-select, and confirm prompts."
license       = "MIT"
srcDir        = "src"
skipDirs      = @["build", "PLANS"]


# Dependencies

requires "nim >= 2.0.0"
requires "https://github.com/titanomachy/terminal-screen#@head"
requires "https://github.com/titanomachy/terminal-style >= 0.1.1"


# Tasks

task compilePackage, "Compile terminal_prompt into the build directory":
  exec "nim c --path:src src/terminal_prompt.nim"

task test, "Run the terminal_prompt test suite":
  exec "nim c -r --path:src tests/test_contracts.nim"
  exec "nim c -r --path:src tests/test_milestone1.nim"
  exec "nim c -r --path:src tests/test_editor.nim"
  exec "nim c -r --path:src tests/test_milestone2.nim"

task examples, "Check that all terminal_prompt examples compile":
  exec "nim check --path:src examples/contracts.nim"

task docs, "Generate terminal_prompt API documentation":
  exec "nim doc --project --index:on --outdir:build/docs --path:src src/terminal_prompt.nim"

task releaseCheck, "Run the local release-readiness checks":
  exec "nimble check"
  exec "nimble compilePackage"
  exec "nimble test"
  exec "nimble examples"
  exec "nimble docs"
