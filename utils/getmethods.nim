# Just a simple program to get all API methods in VK API
import httpclient
import os
import strutils
import json
import tables

let htmlData = newHttpClient().getContent("http://vk.com/dev/methods")
let jsonData = parseJson(htmlData.split("cur.sections = ")[1].split(";\ncur.sect")[0])

var methods = newSeq[string]()
for section, data in jsonData.getFields():
  if "list" notin data: 
    continue
  
  for apiInfo in data["list"].getElems():
    if apiInfo.kind != JArray:
      continue
    methods.add(apiInfo[0].getStr())

writeFile(getAppDir() / ".." / "methods.txt", methods.join(","))