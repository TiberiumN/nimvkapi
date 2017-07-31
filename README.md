# VK API for Nim

Documentation can be found [here](https://tiberiumn.github.io/nimvkapi/)

This is the wrapper for vk.com API written in @nim-lang
It gives you the ability to call vk.com API methods using synchronous and asynchronous approach.

In addition this module exposes macro ``@`` to ease calling API methods

**vk.com API works only on HTTPS, so you need to use `-d:ssl` compilation flag:**
> `nim c -d:ssl myapp.nim`

Here are some simple examples of usage:

Get first name of Pavel Durov, creator of the VK social network
```nim
import vkapi
# We can some VK API methods without authorization
# Create new API object
let api = newVkApi()
# Call users.get method with user_id = 1 parameter
let data = api.request("users.get", {"user_id": "1"}.toApi)
# data is JsonNode, so we'll need to get first element from this json array
# and get first_name field. You can go to VK API documentation for info
# on object fields
echo data[0]["first_name"].str
```

This example can be also rewritten using `@` macro:

```nim
import vkapi
let api = newVkApi()
echo api@users.get(user_id=1)[0]["first_name"].str
```

Add "Hello world from Nim Language!" post to your wall. Only you and your friends could see it:
```nim
let api = newVkApi()
api.login("login", "password")
api@wall.post(friends_only=1, message="Hello world from Nim Language!")
```

Print IDs of all your friends who is currently online from the phone:
```nim
import vkapi
let api = newVkApi()
api.login("your login", "your password")
for id in api@friends.getOnline(online_mobile=1)["online_mobile"]:
  echo id
```

In what cities you have most of your friends?
```nim
import vkapi, strutils, tables

let api = newVkApi()
let table = newCountTable[string]()
api.login("login", "password")

for friend in api@friends.get(fields="city")["items"]:
  if "city" in friend:
    table.inc friend["city"]["title"].str

table.sort()
for key, val in table:
  echo("$1 people lives in $2" % [key, $val])
```