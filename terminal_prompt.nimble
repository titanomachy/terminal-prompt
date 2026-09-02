import std/[algorithm, os, strutils]

# Package

version       = "0.1.1"
author        = "titanomachy"
description   = "Pure-Nim terminal input boxes, password masking, single-select, multi-select, and confirm prompts."
license       = "MIT"
srcDir        = "src"
skipDirs      = @["build", "PLANS"]


# Dependencies

requires "nim >= 2.0.0"
requires "https://github.com/titanomachy/terminal-screen.git >= 0.1.0"
requires "terminal_style >= 0.1.1"


# Tasks

const testFiles = [
  "tests/test_contracts.nim",
  "tests/test_runtime.nim",
  "tests/test_editor.nim",
  "tests/test_line_prompts.nim",
  "tests/test_selection_prompts.nim",
  "tests/test_compatibility.nim",
  "tests/test_strategy.nim",
  "tests/test_build_policy.nim"
]

proc runTests(memoryManager = "") =
  let memoryManagerFlag =
    if memoryManager.len == 0: ""
    else: " --mm:" & memoryManager
  for testFile in testFiles:
    exec "nim c -r" & memoryManagerFlag & " --path:src " & testFile

task compilePackage, "Compile terminal_prompt into the build directory":
  exec "nim c --path:src src/terminal_prompt.nim"

task test, "Run the terminal_prompt test suite":
  runTests()

task testArc, "Run the terminal_prompt test suite with ARC":
  runTests("arc")

task testOrc, "Run the terminal_prompt test suite with ORC":
  runTests("orc")

task testMemoryManagers, "Run the test suite with ARC and ORC":
  runTests("arc")
  runTests("orc")

task examples, "Check that all terminal_prompt examples compile":
  var exampleFiles: seq[string]
  for exampleFile in listFiles("examples"):
    if exampleFile.endsWith(".nim"):
      exampleFiles.add exampleFile
  exampleFiles.sort()
  for exampleFile in exampleFiles:
    exec "nim check --path:src " & quoteShell(exampleFile)

task benchmark, "Benchmark large interactive selection lists":
  exec "nim c -d:release -r --path:src benchmarks/large_selection_lists.nim"

task docs, "Generate public API and internal module documentation":
  exec "nim doc --skipParentCfg:on --project --index:on --outdir:build/docs --path:src src/terminal_prompt.nim"

task releaseCheck, "Run the local release-readiness checks":
  exec "nimble check"
  exec "nimble compilePackage"
  exec "nimble test"
  exec "nimble examples"
  exec "nimble docs"
