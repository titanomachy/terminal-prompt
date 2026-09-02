import std/[os, strutils, unittest]

let repositoryDir = currentSourcePath().parentDir.parentDir
let buildDir = repositoryDir / "build"

proc isWithin(path, parent: string): bool =
  let relative = relativePath(path.absolutePath, parent.absolutePath)
  relative != ".." and
    not relative.startsWith(".." & $DirSep)

proc compilerArtifactsOutsideBuild(): seq[string] =
  const generatedExtensions = [".dll", ".dylib", ".exe", ".o", ".obj", ".so"]
  for sourceDir in ["src", "tests", "examples", "benchmarks"]:
    for path in walkDirRec(repositoryDir / sourceDir):
      let (directory, name, extension) = path.splitFile
      if extension.toLowerAscii in generatedExtensions or
          path.endsWith(".nim.c") or
          (extension.len == 0 and fileExists(directory / (name & ".nim"))):
        result.add relativePath(path, repositoryDir)
      elif (DirSep & "nimcache" & DirSep) in path:
        result.add relativePath(path, repositoryDir)

suite "Nimble and build policy":
  test "test executables are emitted beneath build":
    check getAppFilename().isWithin(buildDir)

  test "compiler products do not leak into source directories":
    let leakedArtifacts = compilerArtifactsOutsideBuild()
    check leakedArtifacts == newSeq[string]()

  test "Git and Nimble exclude generated and planning directories":
    let ignoreRules = readFile(repositoryDir / ".gitignore").splitLines
    let packageMetadata = readFile(repositoryDir / "terminal_prompt.nimble")
    check "/build/" in ignoreRules
    check "skipDirs      = @[\"build\", \"PLANS\"]" in packageMetadata

  test "dependencies use compatible tagged constraints":
    let packageMetadata = readFile(repositoryDir / "terminal_prompt.nimble")
    check "requires \"nim >= 2.0.0\"" in packageMetadata
    check "requires \"https://github.com/titanomachy/terminal-screen.git >= 0.1.0\"" in packageMetadata
    check "requires \"terminal_style >= 0.1.1\"" in packageMetadata
    check "#70de4d47047166871750da34ec6af02a97782ac6" notin packageMetadata
