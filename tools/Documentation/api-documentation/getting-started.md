# 🔑 Getting started

The Client API allows you to communicate with a running LANraragi instance from a dedicated client. All the (public)endpoints below can be tested on the demo!

## Authenticating with the API

Most of the API endpoints require a form of authentication.

Said authentication is provided by a configurable **API Key,** which is set by the user in the LRR settings.

This key must be added to your calls as an `Authentication: Bearer` header, with the key encoded in base64:

```bash
DELETE /api/search/cache HTTP/1.1
Accept: application/json
Authorization: Bearer SEVBVEhFTg==
```

If you fail to meet this requirement, the API endpoint will return error 401 and the following JSON:

```
{
    "error":"This API is protected and requires login or an API Key."
}
```

{% hint style="warning" %}
If the user's LRR installation is running under **No-Fun Mode**, all API methods will be locked behind the key.\
Empty API Keys will **not** work, even if there's no key set in Configuration.
{% endhint %}

Private endpoints will be indicated by a 🔑 symbol next to their name in the following sections.
