## This module is wrapper for vk.com API.
##
## It gives ability to call vk.com API method using synchronius and asynchronius approach.
##
## In addition this module exposes two macros ``@`` and ``@>`` to make API calls in more convenient manner
##
## Here is an examples of how to use this module
##
## Initialization::
##
##    var vk_api = initVkApi(access_key="you key here") # Sync VkApi
##    var async_vk_api = initAsyncVkApi(access_key="you key here") # Async VkApi
##
## Sync examples with simple ``api_request`` calls, and macros calls::
##
##    echo vk_api.api_request("friends.getOnline")
##    echo vk_api.api_request("fave.getPosts", {"count": "1"}.newTable)
##    echo vk_api.api_request("wall.post", {"friends_only"="1", "message"="Hello world fom nim-lang"}.newTable, isPost=true)
##
##    echo vk_api@friends.getOnline()
##    echo vk_api@fave.getPosts(count=1)
##    vk_api@>wall.post(friends_only=1, message="Hello world fom nim-lang")
##
## Async examples with simple ``api_request`` calls, and macros calls::
##
##    import asyncdispatch
##    echo waitFor vk_api.api_request("wall.get", {"count": "1"}.newTable)
##    echo waitFor vk_api@wall.get(count=1)

import httpclient, strutils
import asyncdispatch, asyncnet
import macros
import cgi
import tables
export tables

const VK_URL* = "https://api.vk.com/method/" ## Default API url for vk.com API method calls
type
    VkApi* = object
        ## Object for sync API call to vk.com
        access_key*: string
        version*: string
        api_url*: string
        client*: HttpClient
    AsyncVkApi* = object
        ## Object for async API call to vk.com
        access_key*: string
        version*: string
        api_url*: string
        client*: AsyncHttpClient

proc initVkApi*(access_key, version="5.52", api_url=VK_URL): VkApi =
    ## Initialize ``VkApi`` sync object. Here you have to setup access_key and optionaly setup version and API url
    result.access_key = access_key
    result.api_url = api_url
    result.version = version
    result.client = newHttpClient()

proc initAsyncVkApi*(access_key, version="5.52", api_url=VK_URL): AsyncVkApi =
    ## Initialize ``AsyncVkApi`` async object. Here you have to setup access_key and optionaly setup version and API url
    result.access_key = access_key
    result.api_url = api_url
    result.version = version
    result.client = newAsyncHttpClient()

proc encodeParams(params: TableRef[string, string], isPost = true): string =
  if params.isNil(): return ""
  result = if not isPost: "?" else: ""
  var parts = newSeq[string]()
  for key, val in pairs(params):
    let 
      enck = cgi.encodeUrl(key)
      encv = cgi.encodeUrl(val)
    parts.add($enck & "=" & $encv)
  result.add(parts.join("&"))

proc api_request*(vk_api: VkApi | AsyncVkApi, api_method: string, params: TableRef[string, string]=nil, isPost=false): Future[string] {.multisync.} =
    ## Main method for request vk.com API.
    ##
    ## - ``vk_api`` - is API object (``VkApi`` or ``AsyncVkApi``)
    ## - ``api_method`` - namespace and method separated with dot from vk.com documentation (https://vk.com/dev/methods)
    ## - ``params`` - is Table of method's parameters and there values
    ## - ``return`` - returns API response text as string.
    ## Examples::
    ##
    ##    echo vk_api.api_request("friends.getOnline")
    ##    echo vk_api.api_request("fave.getPosts", {"count": "1"}.newTable)
    ##    echo vk_api.api_request("wall.post", {"friends_only"="1", "message"="Hello world fom nim-lang"}.newTable, isPost=true)
    var
        url = vk_api.api_url
        post_params = ""
        api_params: TableRef[string, string]
    if not params.isNil():
        api_params = params
    else:
        api_params = newTable[string, string]()
    api_params["v"] = vk_api.version
    api_params["access_token"] = vk_api.access_key
    url.add(api_method)
    if not isPost:
        url.add(encodeParams(api_params, isPost))
    else:
        post_params = encodeParams(api_params, isPost)
    if isPost:
        return await vk_api.client.postContent(url, body=post_params)
    else:
        return await vk_api.client.getContent(url)

macro `@`* (name: typed, body: untyped): untyped =
    ## This macros gives ability to make API calls in more convenient manner
    ##
    ## This is infix macros.
    ##
    ## Left argument is ``VkApi`` or ``AsyncVkApi`` object. Right is namespace and method name separated by dot.
    ##
    ## And finaly in parentheses you can specify any number of named arguments.
    ##
    ## This macros converts to ``api_equest`` with ``isPost=false`` and makes GET request to API
    ## Examples::
    ##
    ##    echo vk_api@friends.getOnline()
    ##    echo vk_api@fave.getPosts(count=1, offset=50)

    result = newNimNode(nnkCall)
    var tmpTable = newNimNode(nnkTableConstr)
    result.add(ident("api_request"))
    if body.kind != nnkCall:
        quit "Syntax error"
    if body[0].kind != nnkDotExpr:
        quit "Syntax error"
    result.add(name)
    result.add(body[0].toStrLit)
    if body.len > 1:
        for arg in body.children:
            case arg.kind:
            of nnkExprEqExpr:  
                if arg[1].kind == nnkIdent or arg[1].kind == nnkStrLit:
                    tmpTable.add(newColonExpr(arg[0].toStrLit, arg[1]))
                else: 
                    tmpTable.add(newColonExpr(arg[0].toStrLit, arg[1].toStrLit))
            else: discard
        if tmpTable.len > 0:
            result.add(newNimNode(nnkExprEqExpr).add(ident("params"), newCall("newTable", tmpTable)))

macro `@>`* (name: typed, body: untyped): untyped =
    ## This macros gives ability to make API calls in more convenient manner
    ##
    ## This is infix macros.
    ##
    ## Left argument is ``VkApi`` or ``AsyncVkApi`` object. Right is namespace and method name separated by dot.
    ##
    ## And finaly in parentheses you can specify any number of named arguments.
    ##
    ## This macros converts to ``api_equest`` with ``isPost=true`` and makes POST request to API
    ## Examples::
    ##
    ##    echo vk_api@>wall.post(friends_only=1, message="Hello world fom nim-lang")

    result = newNimNode(nnkCall)
    var tmpTable = newNimNode(nnkTableConstr)
    result.add(ident("api_request"))
    if body.kind != nnkCall:
        quit "Syntax error"
    if body[0].kind != nnkDotExpr:
        quit "Syntax error"
    result.add(name)
    result.add(body[0].toStrLit)
    if body.len > 1:
        for arg in body.children:
            case arg.kind:
            of nnkExprEqExpr:  
                if arg[1].kind == nnkIdent or arg[1].kind == nnkStrLit:
                    tmpTable.add(newColonExpr(arg[0].toStrLit, arg[1]))
                else: 
                    tmpTable.add(newColonExpr(arg[0].toStrLit, arg[1].toStrLit))
            else: discard
        if tmpTable.len > 0:
            result.add(newNimNode(nnkExprEqExpr).add(ident("params"), newCall("newTable", tmpTable)))
    result.add(newNimNode(nnkExprEqExpr).add(ident("isPost"), ident("true") ))

