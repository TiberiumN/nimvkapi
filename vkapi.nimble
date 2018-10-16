# Package

version       = "1.3.0"
author        = "TiberiumN (Daniil Yarancev)"
description   = "Wrapper for vk.com API"
license       = "MIT"

skipDirs      = @["docs"]
# Dependencies

requires "nim >= 0.19.0"

task updateApi, "Update API method names":
  exec "nim c -r utils/getmethods"

task makeDocs, "Update the .html doc file":
  exec "nim doc -o=docs/index.html vkapi"