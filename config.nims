## Keep compiler products out of the source tree.
import std/os

let buildDir = thisDir() / "build"
let isNimDocHelper = getCommand() == "js" and projectName() == "dochack"
if not isNimDocHelper:
  # Nim 2.0 runs this compiler-owned helper as a nested build and expects its
  # output beside the helper source. Redirecting it makes `nim doc` fail.
  switch("outDir", buildDir)
  switch("nimcache", buildDir / "nimcache")

# begin Nimble config (version 2)
when withDir(thisDir(), system.fileExists("nimble.paths")):
  include "nimble.paths"
# end Nimble config
