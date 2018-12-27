---
description: >-
  The Client API allows you to communicate with a running LANraragi instance
  from another client, for instance. All those endpoints can be tested on the
  demo!
---

# Client API

## About the API Key

If your LRR installation is running under **No-Fun Mode**, those API methods will be locked behind a configurable **API Key**. This key will have to be added to the API calls with the _key_ parameter.

Otherwise, the API can be used as-is.

{% hint style="warning" %}
Empty API Keys will **not** work, even if there's no key set in Configuration. key
{% endhint %}

{% api-method method="get" host="http://lrr.tvc-16.science" path="/api/archivelist" %}
{% api-method-summary %}
Get the Archive Index
{% endapi-method-summary %}

{% api-method-description %}
Get the Archive Index in JSON form. You can use the IDs of this JSON with the other endpoints.
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}
{% api-method-path-parameters %}
{% api-method-parameter name="key" type="string" required=false %}
API Key if needed.
{% endapi-method-parameter %}
{% endapi-method-path-parameters %}
{% endapi-method-request %}

{% api-method-response %}
{% api-method-response-example httpCode=200 %}
{% api-method-response-example-description %}
Archive List successfully retrieved. You can use the arcid parameters with the other endpoints.
{% endapi-method-response-example-description %}

```javascript
[{
    "arcid": "ec9b83b6a835771b0f9862d0326add2f8373989a",
    "isnew": "none",
    "tags": "",
    "title": "Ghost in the Shell 01.5 - Human-Error Processor v01c01"
}, {
    "arcid": "28697b96f0ac5858be2614ed10ca47742c9522fd",
    "isnew": "none",
    "tags": "parody:fate grand order,  group:wadamemo,  artist:wada rco,  artbook,  full color",
    "title": "Fate GO MEMO"
}, {
    "arcid": "2810d5e0a8d027ecefebca6237031a0fa7b91eb3",
    "isnew": "none",
    "tags": "parody:fate grand order,  character:abigail williams,  character:artoria pendragon alter,  character:asterios,  character:ereshkigal,  character:gilgamesh,  character:hans christian andersen,  character:hassan of serenity,  character:hector,  character:helena blavatsky,  character:irisviel von einzbern,  character:jeanne alter,  character:jeanne darc,  character:kiara sessyoin,  character:kiyohime,  character:lancer,  character:martha,  character:minamoto no raikou,  character:mochizuki chiyome,  character:mordred pendragon,  character:nitocris,  character:oda nobunaga,  character:osakabehime,  character:penthesilea,  character:queen of sheba,  character:rin tosaka,  character:saber,  character:sakata kintoki,  character:scheherazade,  character:sherlock holmes,  character:suzuka gozen,  character:tamamo no mae,  character:ushiwakamaru,  character:waver velvet,  character:xuanzang,  character:zhuge liang,  group:wadamemo,  artist:wada rco,  artbook,  full color",
    "title": "Fate GO MEMO 2"
}, {
    "arcid": "e69e43e1355267f7d32a4f9b7f2fe108d2401ebf",
    "isnew": "none",
    "tags": "character:segata sanshiro",
    "title": "Saturn Backup Cartridge - Japanese Manual"
}, {
    "arcid": "e4c422fd10943dc169e3489a38cdbf57101a5f7e",
    "isnew": "none",
    "tags": "parody: jojo's bizarre adventure",
    "title": "Rohan Kishibe goes to Gucci"
}]
```
{% endapi-method-response-example %}

{% api-method-response-example httpCode=401 %}
{% api-method-response-example-description %}
You didn't specify an API Key whereas it was needed.
{% endapi-method-response-example-description %}

```javascript
{
    "error":"This API is protected and requires login or an API Key."
}
```
{% endapi-method-response-example %}
{% endapi-method-response %}
{% endapi-method-spec %}
{% endapi-method %}

{% api-method method="get" host="http://lrr.tvc-16.science" path="/api/thumbnail" %}
{% api-method-summary %}
Get the Thumbnail of an Archive
{% endapi-method-summary %}

{% api-method-description %}
Get the Thumbnail image for a given Archive.
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}
{% api-method-path-parameters %}
{% api-method-parameter name="key" type="string" required=false %}
API Key, if needed.
{% endapi-method-parameter %}

{% api-method-parameter name="id" type="string" required=true %}
ID of the Archive to process.
{% endapi-method-parameter %}
{% endapi-method-path-parameters %}
{% endapi-method-request %}

{% api-method-response %}
{% api-method-response-example httpCode=200 %}
{% api-method-response-example-description %}
You get the image diirectly.
{% endapi-method-response-example-description %}

{% code-tabs %}
{% code-tabs-item title="2810d5e0a8d027ecefebca6237031a0fa7b91eb3.jpg" %}
```text

```
{% endcode-tabs-item %}
{% endcode-tabs %}
{% endapi-method-response-example %}

{% api-method-response-example httpCode=400 %}
{% api-method-response-example-description %}
You didn't specify the id parameter.
{% endapi-method-response-example-description %}

```javascript
{
    "error":"API usage: thumbnail?id=YOUR_ID"
}
```
{% endapi-method-response-example %}

{% api-method-response-example httpCode=401 %}
{% api-method-response-example-description %}
You didn't specify an API Key whereas it was needed.
{% endapi-method-response-example-description %}

```javascript
{
    "error":"This API is protected and requires login or an API Key."
}
```
{% endapi-method-response-example %}
{% endapi-method-response %}
{% endapi-method-spec %}
{% endapi-method %}

{% api-method method="get" host="http://lrr.tvc-16.science" path="/api/extract" %}
{% api-method-summary %}
Extract an Archive
{% endapi-method-summary %}

{% api-method-description %}
Extract an Archive on the server, and get a list of URLs pointing to its images.
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}
{% api-method-path-parameters %}
{% api-method-parameter name="key" type="string" required=false %}
API Key, if needed.
{% endapi-method-parameter %}

{% api-method-parameter name="id" type="string" required=true %}
ID of the Archive to process.
{% endapi-method-parameter %}
{% endapi-method-path-parameters %}
{% endapi-method-request %}

{% api-method-response %}
{% api-method-response-example httpCode=200 %}
{% api-method-response-example-description %}
The Archive is extracted server-side and you can now get its images.
{% endapi-method-response-example-description %}

```javascript
{
    "pages": [".\/temp\/28697b96f0ac5858be2614ed10ca47742c9522fd\/00.jpg",
        ".\/temp\/28697b96f0ac5858be2614ed10ca47742c9522fd\/01.jpg",
        ".\/temp\/28697b96f0ac5858be2614ed10ca47742c9522fd\/03.jpg",
        ".\/temp\/28697b96f0ac5858be2614ed10ca47742c9522fd\/04.jpg",
        ".\/temp\/28697b96f0ac5858be2614ed10ca47742c9522fd\/05.jpg",
        ".\/temp\/28697b96f0ac5858be2614ed10ca47742c9522fd\/06.jpg",
        ".\/temp\/28697b96f0ac5858be2614ed10ca47742c9522fd\/07.jpg",
        ".\/temp\/28697b96f0ac5858be2614ed10ca47742c9522fd\/08.jpg",
        ".\/temp\/28697b96f0ac5858be2614ed10ca47742c9522fd\/09.jpg",
        ".\/temp\/28697b96f0ac5858be2614ed10ca47742c9522fd\/20.jpg",
        ".\/temp\/28697b96f0ac5858be2614ed10ca47742c9522fd\/21.jpg",
        ".\/temp\/28697b96f0ac5858be2614ed10ca47742c9522fd\/22.jpg",
        ".\/temp\/28697b96f0ac5858be2614ed10ca47742c9522fd\/23.jpg",
        ".\/temp\/28697b96f0ac5858be2614ed10ca47742c9522fd\/24.jpg",
        ".\/temp\/28697b96f0ac5858be2614ed10ca47742c9522fd\/25.jpg",
        ".\/temp\/28697b96f0ac5858be2614ed10ca47742c9522fd\/26.jpg",
        ".\/temp\/28697b96f0ac5858be2614ed10ca47742c9522fd\/27.jpg",
        ".\/temp\/28697b96f0ac5858be2614ed10ca47742c9522fd\/28.jpg",
        ".\/temp\/28697b96f0ac5858be2614ed10ca47742c9522fd\/29.jpg",
        ".\/temp\/28697b96f0ac5858be2614ed10ca47742c9522fd\/30.jpg",
        ".\/temp\/28697b96f0ac5858be2614ed10ca47742c9522fd\/31.jpg",
        ".\/temp\/28697b96f0ac5858be2614ed10ca47742c9522fd\/32.jpg",
        ".\/temp\/28697b96f0ac5858be2614ed10ca47742c9522fd\/33.jpg",
        ".\/temp\/28697b96f0ac5858be2614ed10ca47742c9522fd\/34.jpg",
        ".\/temp\/28697b96f0ac5858be2614ed10ca47742c9522fd\/35.jpg",
        ".\/temp\/28697b96f0ac5858be2614ed10ca47742c9522fd\/36.jpg",
        ".\/temp\/28697b96f0ac5858be2614ed10ca47742c9522fd\/37.jpg",
        ".\/temp\/28697b96f0ac5858be2614ed10ca47742c9522fd\/38.jpg",
        ".\/temp\/28697b96f0ac5858be2614ed10ca47742c9522fd\/39.jpg",
        ".\/temp\/28697b96f0ac5858be2614ed10ca47742c9522fd\/40.jpg"
    ]
}
```
{% endapi-method-response-example %}

{% api-method-response-example httpCode=400 %}
{% api-method-response-example-description %}
You didn't include the id parameter.
{% endapi-method-response-example-description %}

```javascript
{
    "error":"API usage: extract?id=YOUR_ID"
}
```
{% endapi-method-response-example %}

{% api-method-response-example httpCode=401 %}
{% api-method-response-example-description %}
You didn't include the key parameter.
{% endapi-method-response-example-description %}

```javascript
{
    "error":"This API is protected and requires login or an API Key."
}
```
{% endapi-method-response-example %}
{% endapi-method-response %}
{% endapi-method-spec %}
{% endapi-method %}

{% api-method method="get" host="http://lrr.tvc-16.science" path="/api/servefile" %}
{% api-method-summary %}
Download an Archive
{% endapi-method-summary %}

{% api-method-description %}
Download an Archive from the server.
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}
{% api-method-path-parameters %}
{% api-method-parameter name="key" type="string" required=false %}
API Key, if needed.
{% endapi-method-parameter %}

{% api-method-parameter name="id" type="string" required=true %}
ID of the Archive to download.
{% endapi-method-parameter %}
{% endapi-method-path-parameters %}
{% endapi-method-request %}

{% api-method-response %}
{% api-method-response-example httpCode=200 %}
{% api-method-response-example-description %}
You get the Archive.
{% endapi-method-response-example-description %}

{% code-tabs %}
{% code-tabs-item title="Archive.zip" %}
```text

```
{% endcode-tabs-item %}
{% endcode-tabs %}
{% endapi-method-response-example %}

{% api-method-response-example httpCode=400 %}
{% api-method-response-example-description %}

{% endapi-method-response-example-description %}

```javascript
{
    "error":"API usage: servefile?id=YOUR_ID"
}
```
{% endapi-method-response-example %}

{% api-method-response-example httpCode=401 %}
{% api-method-response-example-description %}
You didn't include the key parameter.
{% endapi-method-response-example-description %}

```javascript
{
    "error":"This API is protected and requires login or an API Key."
}
```
{% endapi-method-response-example %}
{% endapi-method-response %}
{% endapi-method-spec %}
{% endapi-method %}

