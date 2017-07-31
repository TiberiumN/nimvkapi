## This module is a wrapper for vk.com API.
##
## It gives you the ability to call vk.com API methods using synchronous and asynchronous approach.
##
## In addition this module exposes macro ``@`` to ease calling API methods
##
## Initialization
## ====================
##
## .. code-block:: Nim
##    # Synchronous VK API
##    let api = newVkApi(token="you access token here")
##    # Asynchronous VK API
##    let asyncApi = newAsyncVkApi(token="you access token here")
##
## Synchronous VK API usage
## ====================
##
## .. code-block:: Nim
##    echo api.apiRequest("friends.getOnline")
##    echo api.apiRequest("fave.getPosts", {"count": "1"}.newTable)
##    echo api.apiRequest("wall.post", {"friends_only": "1", "message": "Hello world from nim-lang"}.toApi)
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
##    echo waitFor asyncApi.apiRequest("wall.get", {"count": "1"}.toApi)
##    echo waitFor asyncApi@wall.get(count=1)

# HTTP client
import httpclient
# `join` procedure
import strutils
# Async and multisync features
import asyncdispatch
# `@` macro
import macros
# URL encoding
import cgi
# String tables
import strtabs
export strtabs


const 
  VkUrl* = "https://api.vk.com/method/"  ## Default API url for vk.com API method calls

  ApiVer* = "5.67" ## Default API version

type
  VkApiBase*[HttpType] = ref object  ## VK API object base
    token*: string  ## VK API token
    version*: string  ## VK API version
    url*: string  ## VK API url
    when HttpType is HttpClient: client: HttpClient
    else: client: AsyncHttpClient
  
  VkApi* = VkApiBase[HttpClient] ## VK API object for doing synchronous requests
  
  AsyncVkApi* = VkApiBase[AsyncHttpClient] ## VK API object for doing asynchronous requests

proc newVkApi*(token = "", version = ApiVer, url = VkUrl): VkApi =
  ## Initialize ``VkApi`` object.
  ##
  ## - ``token`` - your VK API access token
  ## - ``version`` - VK API version
  ## - ``url`` - VK API url
  new(result)
  result.token = token
  result.url = url
  result.version = version
  result.client = newHttpClient()

proc newAsyncVkApi*(token = "", version = ApiVer, url = VkUrl): AsyncVkApi =
  ## Initialize ``AsyncVkApi`` object.
  ##
  ## - ``token`` - your VK API access token
  ## - ``version`` - VK API version
  ## - ``url`` - VK API url
  new(result)
  result.token = token
  result.url = url
  result.version = version
  result.client = newAsyncHttpClient()

proc encode(params: StringTableRef): string =
  result = ""
  var parts = newSeq[string]()
  for key, val in pairs(params):
    let 
      enck = cgi.encodeUrl(key)
      encv = cgi.encodeUrl(val)
    parts.add($enck & "=" & $encv)
  result.add(parts.join("&"))

proc apiRequest*(api: VkApi | AsyncVkApi, name: string, 
                 params = newStringTable()): Future[string] {.multisync.} =
  ## Main method for  VK API requests.
  ##
  ## - ``api`` - API object (``VkApi`` or ``AsyncVkApi``)
  ## - ``name`` - namespace and method separated with dot (https://vk.com/dev/methods)
  ## - ``params`` - StringTable with parameters
  ## - ``return`` - returns API response text as string.
  ## Examples:
  ##
  ## .. code-block:: Nim
  ##    echo api.apiRequest("friends.getOnline")
  ##    echo api.apiRequest("fave.getPosts", {"count": "1"}.toApi)
  ##    echo api.apiRequest("wall.post", {"friends_only": "1", "message": "Hello world from nim-lang"}.toApi)
  params["v"] = api.version
  params["access_token"] = api.token
  return await api.client.postContent(api.url & name, body=params.encode())

macro `@`* (api: VkApi | AsyncVkApi, body: untyped): untyped =
  ## `@` macro gives you the ability to make API calls in more convenient manner
  ##
  ## Left argument is ``VkApi`` or ``AsyncVkApi`` object. 
  ## Right one is a namespace and method name separated by dot.
  ##
  ## And finally in parentheses you can specify any number of named arguments.
  ##
  ##
  ## This macro is transformed into ``apiRequest`` call with parameters 
  ##
  ## Example:
  ##
  ## .. code-block:: Nim
  ##    echo api@friends.getOnline()
  ##    echo api@fave.getPosts(count=1, offset=50)
  assert body.kind == nnkCall
  # Let's create a table, which will have API parameters
  var table = newNimNode(nnkTableConstr)
  # Full API method name
  let name = body[0].toStrLit
  # Check all arguments inside of call
  for arg in body.children:
    # If it's a equality expression "abcd=something"
    if arg.kind == nnkExprEqExpr:
      # We need to convert value to the appropriate format
      let value = if arg[1].kind in {nnkIdent, nnkStrLit}: arg[1]
                  else: arg[1].toStrLit
      # Add it to our API parameters table 
      table.add(newColonExpr(arg[0].toStrLit, value))
  # Finally create a statement to call API
  result = quote do:
    `api`.apiRequest(`name`, `table`.toApi)