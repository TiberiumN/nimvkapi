# nimvkapi
Contains a wrapper for the vk.com API written in nim lang

This module is a wrapper for vk.com API.
It gives you the ability to call vk.com API methods using synchronous and asynchronous approach.

In addition this module exposes macro ``@`` to ease calling API methods

> vk.com uses https, so you need to use `-d:ssl` compilation flag
>
> Example: `nim c -d:ssl -r myvkapp.nim`

Here is some examples of how to use this module

Initialization:
```nim
import vkapi

# Synchronous VK API
let api = newVkApi(token="you access token here")

# Asynchronous VK API
let asyncApi = newAsyncVkApi(token="you access token here")
```

Synchronous VK API examples:
```nim
# simple apiRequest
echo api.apiRequest("friends.getOnline")
echo api.apiRequest("fave.getPosts", {"count": "1"}.toApi)
echo api.apiRequest("wall.post", {"friends_only"="1", "message"="Hello world from nim-lang"}.toApi)

# awesome beautiful macros
echo api@friends.getOnline()
echo api@fave.getPosts(count=1)
echo api@wall.post(friends_only=1, message="Hello world fom nim-lang")
```

Asynchronous VK API examples:
```nim
import asyncdispatch
echo waitFor asyncApi.apiRequest("wall.get", {"count": "1"}.toApi)
echo waitFor asyncApi@wall.get(count=1)
```

## `@` macro

`@` macro gives you the ability to make API calls in more convenient manner

Left argument is ``VkApi`` or ``AsyncVkApi`` object. Right is a namespace and method name separated by dot.

And finally in parentheses you can specify any number of named arguments.

`@` macro converts your requests to ``apiRequest`` calls
Example:
```nim
echo api@friends.getOnline()
echo api@fave.getPosts(count=1, offset=50)
echo api@wall.post(friends_only=1, message="Hello world fom nim-lang")
```

## How to get access key for API
To use vk.com api. You need to get `access_key`. 

All information you can get on [Vk manual page](https://vk.com/dev/manuals)

Firstly you need to create your own Standalone Application

You can find other information about access key [here](https://vk.com/dev/first_guide).

And [here](https://vk.com/dev/methods) you can find all available VK API methods
