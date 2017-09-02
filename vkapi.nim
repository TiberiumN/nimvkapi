## This module is a wrapper for vk.com API.
##
## It gives you the ability to call vk.com API methods using synchronous and asynchronous approach.
##
## In addition this module exposes macro ``@`` to ease calling of the API methods
##
## Initialization
## ====================
##
## .. code-block:: Nim
##    # Synchronous VK API
##    let api = newVkApi()
##    # Asynchronous VK API
##    let asyncApi = newAsyncVkApi()
##    # If you want to provide token instead of login and password, use this:
##    let api = newVkApi(token="your token")
##
## Authorization
## ====================
##
## .. code-block:: Nim
##    api.login("your login", "your password")
##    # This library also supports 2-factor authentication:
##    api.login("your login", "your password", "your 2fa code")
##    # Async example:
##    waitFor asyncApi.login("login", "password")
##
## Synchronous VK API usage
## ====================
##
## .. code-block:: Nim
##    echo api.request("friends.getOnline")
##    echo api.request("fave.getPosts", {"count": "1"}.newTable)
##    echo api.request("wall.post", {"friends_only": "1", "message": "Hello world from nim-lang"}.toApi)
##
##    echo api@friends.getOnline()
##    echo api@fave.getPosts(count=1)
##    api@wall.post(friends_only=1, message="Hello world from nim-lang")
##
## Asynchronous VK API usage
## ====================
##
## .. code-block:: Nim
##    import asyncdispatch
##    echo waitFor asyncApi.request("wall.get", {"count": "1"}.toApi)
##    echo waitFor asyncApi@wall.get(count=1)

# HTTP client
import httpclient
# JSON parsing
import json
export json
# `join` and `editDistance` procedures
import strutils
# Async and multisync features
import asyncdispatch
# AST operations
import macros
# URL encoding
import cgi
# String tables
import strtabs
export strtabs

type
  VkApiBase*[HttpType] = ref object  ## VK API object base
    token*: string  ## VK API token
    version*: string  ## VK API version
    client: HttpType
  
  VkApi* = VkApiBase[HttpClient] ## VK API object for doing synchronous requests
  
  AsyncVkApi* = VkApiBase[AsyncHttpClient] ## VK API object for doing asynchronous requests

  VkApiError* = object of Exception  ## VK API Error
  VkAuthError* = object of Exception

const
  ApiUrl = "https://api.vk.com/method/"
  ApiVer* = "5.68" ## Default API version
  AuthScope = "all" ## Default authorization scope
  ClientId = "3140623"  ## Client ID (VK iPhone app)
  ClientSecret = "VeWdmVclDCtn6ihuP1nt"  ## Client secret

when not defined(ssl):
  {.error: "You must compile your program with -d:ssl because VK API uses HTTPS"}

proc sharedInit(base: VkApiBase, tok, ver: string) = 
  base.token = tok
  base.version = ver

proc newVkApi*(token = "", version = ApiVer): VkApi =
  ## Initialize ``VkApi`` object.
  ##
  ## - ``token`` - your VK API access token
  ## - ``version`` - VK API version
  ## - ``url`` - VK API url
  new(result)
  result.sharedInit(token, version)
  result.client = newHttpClient()

proc newAsyncVkApi*(token = "", version = ApiVer): AsyncVkApi =
  ## Initialize ``AsyncVkApi`` object.
  ##
  ## - ``token`` - your VK API access token
  ## - ``version`` - VK API version
  ## - ``url`` - VK API url
  new(result)
  result.sharedInit(token, version)
  result.client = newAsyncHttpClient()

proc encode(params: StringTableRef): string =
  ## Encodes parameters for POST request and returns request body
  var parts = newSeq[string]()
  for key, val in params:
    # Add encoded values to result
    parts.add(encodeUrl(key) & "=" & encodeUrl(val))
  # Join all values by "&" for POST request
  result = parts.join("&")

proc login*(api: VkApi | AsyncVkApi, login, password: string, 
            twoFactorCode = "", scope = AuthScope) {.multisync.} = 
  ## Login in VK using login and password (optionally 2-factor code)
  ##
  ## - ``api`` - VK API object
  ## - ``login`` - VK login
  ## - ``password`` - VK password
  ## - ``code`` - if you have 2-factor auth, you need to provide your 2-factor code
  ## - ``scope`` - authentication scope, default is "all"
  ## Example of usage:
  ##
  ## .. code-block:: Nim
  ##    let api = newVkApi()
  ##    api.login("your login", "your password")
  ##    echo api@users.get()
  let authData = {
    "client_id": ClientId, 
    "client_secret": ClientSecret, 
    "grant_type": "password", 
    "username": login, 
    "password": password, 
    "scope": scope, 
    "v": ApiVer,
    "2fa-supported": "1"
  }.newStringTable()
  if twoFactorCode != "":
    authData["code"] = twoFactorCode
  # Send our request. We don't use postContent since VK can answer 
  # with other HTTP response codes than 200
  let resp = await api.client.post("https://oauth.vk.com/token",
                                    body=authData.encode())
  let answer = parseJson(await resp.body)
  if "error" in answer:
    raise newException(VkAuthError, answer["error_description"].str)
  else:
    api.token = answer["access_token"].str

proc toApi*(data: openarray[tuple[key, val: string]]): StringTableRef = 
  ## Shortcut for newStringTable to create arguments for request call
  data.newStringTable()

proc getErrorMsg(err: JsonNode): string = 
  case err["error_code"].num
  of 3:
    "Unknown VK API method"
  of 5:
    "Authorization failed: invalid access token"
  of 6:
    # TODO: RPS limiter
    "Too many requests per second"
  of 14:
    # TODO: Captcha handler
    "Captcha is required"
  of 17:
    "Need validation code"
  else:
    "Error code $1: $2 " % [$err["error_code"].num, err["error_msg"].str]
  
proc request*(api: VkApi | AsyncVkApi, name: string, 
              params = newStringTable()): Future[JsonNode]
             {.multisync, discardable.} =
  ## Main method for  VK API requests.
  ##
  ## - ``api`` - API object (``VkApi`` or ``AsyncVkApi``)
  ## - ``name`` - namespace and method separated with dot (https://vk.com/dev/methods)
  ## Examples:
  ## - ``params`` - StringTable with parameters
  ## - ``return`` - returns response as JsonNode object
  ##
  ## .. code-block:: Nim
  ##    echo api.request("friends.getOnline")
  ##    echo api.request("fave.getPosts", {"count": "1"}.toApi)
  ##    api@wall.post(friends_only=1, message="Hello world from nim-lang!")
  params["v"] = api.version
  params["access_token"] = api.token
  # Send request to API and parse answer as JSON
  let data = parseJson await api.client.postContent(
    ApiUrl & name, body=params.encode()
  )
  let error = data.getOrDefault("error")
  # If some error happened
  if not error.isNil():
    raise newException(VkApiError, getErrorMsg(error))
  result = data.getOrDefault("response")
  if result.isNil(): result = data

let methods {.compiletime.} = staticRead("methods.txt").split(",")

proc suggestedMethod(name: string): string {.compiletime.} = 
  ## Find suggested method name (with Levenshtein distance)
  var lastDist = 100500
  for entry in methods:
    let dist = editDistance(name, entry)
    if dist < lastDist:
      result = entry
      lastDist = dist

macro `@`*(api: VkApi | AsyncVkApi, body: untyped): untyped =
  ## `@` macro gives you the ability to make API calls using much more easier syntax
  ##
  ## This macro is transformed into ``request`` call with parameters 
  ##
  ## Also this macro checks if provided method name is valid, 
  ## and gives suggestions if it's not
  ##
  ## Some examples:
  ##
  ## .. code-block:: Nim
  ##    echo api@friends.getOnline()
  ##    echo api@fave.getPosts(count=1, offset=50)
  # Copy API object so it wouldn't be a NimNode
  var api = api
  result = body.copy()

  proc getData(node: var NimNode) =
    # Table with API parameters
    var table = newNimNode(nnkTableConstr)
    let mName = node[0].toStrLit
    let mNameStr = $mName
    if mNameStr notin methods:
      error(
        "There's no \"$1\" VK API method. " % mNameStr &
        "Did you mean \"$1\"?" % suggestedMethod(mNameStr), 
        node # Add current node to provide line info
      )
    for arg in node.children:
      # We only accepts arguments like "abcd=something"
      if arg.kind != nnkExprEqExpr: continue
      # Convert key to string, and call $ for value to convert it to string
      table.add(newColonExpr(arg[0].toStrLit, newCall("$", arg[1])))
    node = quote do: 
      `api`.request(`mName`, `table`.toApi())
  
  template isNeeded(n: NimNode): bool = 
    ## Returns true if NimNode is something like 
    ## "users.get(user_id=1)" or "users.get()" or "execute()"
    n.kind == nnkCall and (n[0].kind == nnkDotExpr or $n[0] == "execute")
  
  proc findNeeded(n: NimNode) =
    var i = 0
    # For every children
    for child in n.children:
      # If it's the children we're looking for
      if child.isNeeded():
        # Modify our children with generated info
        var child = child
        child.getData()
        n[i] = child
      else:
        # Recursively call findNeeded on child
        child.findNeeded()
      inc i  # increment index
  
  if result.isNeeded(): result.getData() else: result.findNeeded()