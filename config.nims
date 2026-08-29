## Keep compiler products out of the source tree.
import std/os

let buildDir = thisDir() / "build"
switch("outDir", buildDir)
switch("nimcache", buildDir / "nimcache")

# begin Nimble config (version 2)
when withDir(thisDir(), system.fileExists("nimble.paths")):
  include "nimble.paths"
# end Nimble config
