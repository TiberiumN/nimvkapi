# nimvkapi
Contains a wrapper for the vk.com API written in nim lang

This module is wrapper for vk.com API.
It gives ability to call vk.com API method using synchronius and asynchronius approach.

In addition this module exposes two macros ``@`` and ``@>`` to make API calls in more convenient manner


> vk.com uses https that is why you need to use `-d:ssl` compile flag
>
> Example: `nim c -d:ssl -r myvkapp.nim`

Here is examples of how to use this module

Initialization:
```nim
import vkapi

# Sync VkApi
var vk_api = initVkApi(access_key="you key here")

# Async VkApi
var async_vk_api = initAsyncVkApi(access_key="you key here")
```

Sync examples with simple ``api_request`` calls, and macros calls:
```nim
# simple api_request
echo vk_api.api_request("friends.getOnline")
echo vk_api.api_request("fave.getPosts", {"count": "1"}.newTable)
echo vk_api.api_request("wall.post", {"friends_only"="1", "message"="Hello world fom nim-lang"}.newTable, isPost=true)

# awesome beautiful macros
echo vk_api@friends.getOnline()
echo vk_api@fave.getPosts(count=1)
vk_api@>wall.post(friends_only=1, message="Hello world fom nim-lang")
```

Async examples with simple ``api_request`` calls, and macros calls:
```nim
import asyncdispatch
echo waitFor async_vk_api.api_request("wall.get", {"count": "1"}.newTable)
echo waitFor async_vk_api@wall.get(count=1)
```

> Pay Attention
>
> If you are using macros. 
>
> `@` - this macros for making GET request. For request to read data.
>
> `@>` - this macros for making POST request. To post new data to vk
## macros

`@` and `@>` macros gives ability to make API calls in more convenient manner

This is infix macros.

Left argument is ``VkApi`` or ``AsyncVkApi`` object. Right is namespace and method name separated by dot.

And finaly in parentheses you can specify any number of named arguments.

`@` macros converts to ``api_equest`` with ``isPost=false`` and makes GET request to API
Example:
```nim
echo vk_api@friends.getOnline()
echo vk_api@fave.getPosts(count=1, offset=50)
```

`@>` macros converts to ``api_equest`` with ``isPost=true`` and makes POST request to API
Examples:
```nim
echo vk_api@>wall.post(friends_only=1, message="Hello world fom nim-lang")
```

## Vk api 
To use vk.com api. You need to get `access_key`. 

All information you can get on [Vk manual page](https://vk.com/dev/manuals)

First you need to create Standalone Application

How to get `access_key` you can find [here](https://vk.com/dev/first_guide).

And [here](https://vk.com/dev/methods) all vk.com methods. You can use all this methods with this wrapper.
