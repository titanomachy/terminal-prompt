import std/os

let repositoryDir = thisDir() / ".."
switch("path", repositoryDir / "src")
switch("outDir", repositoryDir / "build")
switch("nimcache", repositoryDir / "build" / "nimcache")
