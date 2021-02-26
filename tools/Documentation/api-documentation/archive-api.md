---
description: Everything dealing with Archives.
---

# Archive API

{% api-method method="get" host="http://lrr.tvc-16.science" path="/api/archives" %}
{% api-method-summary %}
Get all Archives
{% endapi-method-summary %}

{% api-method-description %}
Get the Archive Index in JSON form. You can use the IDs of this JSON with the other endpoints.
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}
{% endapi-method-request %}

{% api-method-response %}
{% api-method-response-example httpCode=200 %}
{% api-method-response-example-description %}
Archive List successfully retrieved. You can use the arcid parameters with the other endpoints.  
The `pagecount` and `progress` values can be both 0 if an archive has never been extracted/read.
{% endapi-method-response-example-description %}

```javascript
[{
    "arcid": "ec9b83b6a835771b0f9862d0326add2f8373989a",
    "isnew": "true",
    "pagecount": 128,
    "progress": 0,
    "tags": "",
    "title": "Ghost in the Shell 01.5 - Human-Error Processor v01c01"
}, {
    "arcid": "28697b96f0ac5858be2614ed10ca47742c9522fd",
    "isnew": "false",
    "pagecount": 34,
    "progress": 3,
    "tags": "parody:fate grand order,  group:wadamemo,  artist:wada rco,  artbook,  full color",
    "title": "Fate GO MEMO"
}, {
    "arcid": "2810d5e0a8d027ecefebca6237031a0fa7b91eb3",
    "isnew": "false",
    "pagecount": 0,
    "progress": 0,
    "tags": "parody:fate grand order,  character:abigail williams,  character:artoria pendragon alter,  character:asterios,  character:ereshkigal,  character:gilgamesh,  character:hans christian andersen,  character:hassan of serenity,  character:hector,  character:helena blavatsky,  character:irisviel von einzbern,  character:jeanne alter,  character:jeanne darc,  character:kiara sessyoin,  character:kiyohime,  character:lancer,  character:martha,  character:minamoto no raikou,  character:mochizuki chiyome,  character:mordred pendragon,  character:nitocris,  character:oda nobunaga,  character:osakabehime,  character:penthesilea,  character:queen of sheba,  character:rin tosaka,  character:saber,  character:sakata kintoki,  character:scheherazade,  character:sherlock holmes,  character:suzuka gozen,  character:tamamo no mae,  character:ushiwakamaru,  character:waver velvet,  character:xuanzang,  character:zhuge liang,  group:wadamemo,  artist:wada rco,  artbook,  full color",
    "title": "Fate GO MEMO 2"
}, {
    "arcid": "e69e43e1355267f7d32a4f9b7f2fe108d2401ebf",
    "isnew": "false",
    "pagecount": 0,
    "progress": 0,
    "tags": "character:segata sanshiro",
    "title": "Saturn Backup Cartridge - Japanese Manual"
}, {
    "arcid": "e4c422fd10943dc169e3489a38cdbf57101a5f7e",
    "isnew": "false",
    "pagecount": 0,
    "progress": 0,
    "tags": "parody: jojo's bizarre adventure",
    "title": "Rohan Kishibe goes to Gucci"
}]
```

{% endapi-method-response-example %}
{% endapi-method-response %}
{% endapi-method-spec %}
{% endapi-method %}

{% api-method method="get" host="http://lrr.tvc-16.science" path="/api/archives/untagged" %}
{% api-method-summary %}
Get Untagged Archives
{% endapi-method-summary %}

{% api-method-description %}
Get archives that don't have any tags recorded. This follows the same rules as the Batch Tagging filter and will include archives that have parody:, date_added:, series: or artist: tags.
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}
{% endapi-method-request %}
{% api-method-response %}
{% api-method-response-example httpCode=200 %}
{% api-method-response-example-description %}
JSON Array of Archive IDs.
{% endapi-method-response-example-description %}

```javascript
[
    "d1858d5dc36925aa66be072a97817650d39de166",
    "c3458d5dc36925da93be072a97817650d39de166",
    "28697b96f0ac5858be2614ed10ca47742c9522fd",
]
```

{% endapi-method-response-example %}
{% endapi-method-response %}
{% endapi-method-spec %}
{% endapi-method %}

{% api-method method="get" host="http://lrr.tvc-16.science" path="/api/archives/:id/metadata" %}
{% api-method-summary %}
Get Archive Metadata
{% endapi-method-summary %}

{% api-method-description %}
Get Metadata (title, tags) for a given Archive.
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}
{% api-method-path-parameters %}
{% api-method-parameter name="id" type="string" required=true %}
ID of the Archive to process.
{% endapi-method-parameter %}
{% endapi-method-path-parameters %}
{% endapi-method-request %}

{% api-method-response %}
{% api-method-response-example httpCode=200 %}
{% api-method-response-example-description %}
You get metadata for the Archive.  
The JSON object supplied follows the same format as the objects returned by the `/api/archives` endpoint.
{% endapi-method-response-example-description %}

```javascript
{
    "arcid": "e69e43e1355267f7d32a4f9b7f2fe108d2401ebf",
    "isnew": "false",
    "pagecount": 34,
    "progress": 3,
    "tags": "character:segata sanshiro",
    "title": "Saturn Backup Cartridge - Japanese Manual"
}
```

{% endapi-method-response-example %}

{% api-method-response-example httpCode=400 %}
{% api-method-response-example-description %}
You didn't specify the id parameter.
{% endapi-method-response-example-description %}

```javascript
{
    "operation": "______"
    "error": "No archive ID specified."
    "status": 0
}
```

{% endapi-method-response-example %}
{% endapi-method-response %}
{% endapi-method-spec %}
{% endapi-method %}

{% api-method method="get" host="http://lrr.tvc-16.science" path="/api/archives/:id/categories" %}
{% api-method-summary %}
Get Archive Categories
{% endapi-method-summary %}

{% api-method-description %}
Get all the Categories which currently refer to this Archive ID.
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}
{% api-method-path-parameters %}
{% api-method-parameter name="id" type="string" required=true %}
ID of the Archive to process.
{% endapi-method-parameter %}
{% endapi-method-path-parameters %}
{% endapi-method-request %}

{% api-method-response %}
{% api-method-response-example httpCode=200 %}
{% api-method-response-example-description %}
You get the categories containing the Archive with their full metadata.  
See the `/api/categories` endpoints for more information.
{% endapi-method-response-example-description %}

```javascript
{
    "categories": [
        {
            "archives": [
                "0d50858d727723d856d2ab78564bb8e906e65f14",
                "7f03b8b1f337e1e42b2c2890533c0de7479d41ca"
            ],
            "id": "SET_1613080290",
            "last_used": "1614298062",
            "name": "My great category",
            "pinned": "0",
            "search": ""
        }
    ],
    "operation": "find_arc_categories",
    "success": 1
}
```

{% endapi-method-response-example %}

{% api-method-response-example httpCode=400 %}
{% api-method-response-example-description %}
You didn't specify the id parameter.
{% endapi-method-response-example-description %}

```javascript
{
    "operation": "______"
    "error": "No archive ID specified."
    "status": 0
}
```

{% endapi-method-response-example %}
{% endapi-method-response %}
{% endapi-method-spec %}
{% endapi-method %}

{% api-method method="get" host="http://lrr.tvc-16.science" path="/api/archives/:id/thumbnail" %}
{% api-method-summary %}
Get Archive Thumbnail
{% endapi-method-summary %}

{% api-method-description %}
Get the Thumbnail image for a given Archive.
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}
{% api-method-path-parameters %}
{% api-method-parameter name="id" type="string" required=true %}
ID of the Archive to process.
{% endapi-method-parameter %}
{% endapi-method-path-parameters %}
{% endapi-method-request %}

{% api-method-response %}
{% api-method-response-example httpCode=200 %}
{% api-method-response-example-description %}
You get the image directly.  
If the thumbnail hasn't been generated by the server yet, you might receive a placeholder image.
{% endapi-method-response-example-description %}

{% tabs %}
{% tab title="2810d5e0a8d027ecefebca6237031a0fa7b91eb3.jpg" %}

```text

```

{% endtab %}
{% endtabs %}
{% endapi-method-response-example %}

{% api-method-response-example httpCode=400 %}
{% api-method-response-example-description %}
You didn't specify the id parameter.
{% endapi-method-response-example-description %}

```javascript
{
    "operation": "______"
    "error": "No archive ID specified."
    "status": 0
}
```

{% endapi-method-response-example %}
{% endapi-method-response %}
{% endapi-method-spec %}
{% endapi-method %}

{% api-method method="get" host="http://lrr.tvc-16.science" path="/api/archives/:id/download" %}
{% api-method-summary %}
Download an Archive
{% endapi-method-summary %}

{% api-method-description %}
Download an Archive from the server.
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}
{% api-method-path-parameters %}
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

{% tabs %}
{% tab title="Archive.zip" %}

```text

```

{% endtab %}
{% endtabs %}
{% endapi-method-response-example %}

{% api-method-response-example httpCode=400 %}
{% api-method-response-example-description %}

{% endapi-method-response-example-description %}

```javascript
{
    "operation": "______"
    "error": "No archive ID specified."
    "status": 0
}
```

{% endapi-method-response-example %}
{% endapi-method-response %}
{% endapi-method-spec %}
{% endapi-method %}

{% api-method method="post" host="http://lrr.tvc-16.science" path="/api/archives/:id/extract" %}
{% api-method-summary %}
Extract an Archive
{% endapi-method-summary %}

{% api-method-description %}
Extract an Archive on the server, and get a list of URLs pointing to its images.
This silently updates the `pagecount` field of the archive.
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}
{% api-method-path-parameters %}
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
    "pages": [".\/api\/archives\/28697b96f0ac5858be2614ed10ca47742c9522fd\/page&path=00.jpg",
        ".\/api\/archives\/28697b96f0ac5858be2614ed10ca47742c9522fd\/page&path=01.jpg",
        ".\/api\/archives\/28697b96f0ac5858be2614ed10ca47742c9522fd\/page&path=03.jpg",
        ".\/api\/archives\/28697b96f0ac5858be2614ed10ca47742c9522fd\/page&path=04.jpg",
        ".\/api\/archives\/28697b96f0ac5858be2614ed10ca47742c9522fd\/page&path=05.jpg",
        ".\/api\/archives\/28697b96f0ac5858be2614ed10ca47742c9522fd\/page&path=06.jpg",
        ".\/api\/archives\/28697b96f0ac5858be2614ed10ca47742c9522fd\/page&path=07.jpg",
        ".\/api\/archives\/28697b96f0ac5858be2614ed10ca47742c9522fd\/page&path=08.jpg",
        ".\/api\/archives\/28697b96f0ac5858be2614ed10ca47742c9522fd\/page&path=09.jpg",
        ".\/api\/archives\/28697b96f0ac5858be2614ed10ca47742c9522fd\/page&path=20.jpg",
        ".\/api\/archives\/28697b96f0ac5858be2614ed10ca47742c9522fd\/page&path=21.jpg",
        ".\/api\/archives\/28697b96f0ac5858be2614ed10ca47742c9522fd\/page&path=22.jpg",
        ".\/api\/archives\/28697b96f0ac5858be2614ed10ca47742c9522fd\/page&path=23.jpg",
        ".\/api\/archives\/28697b96f0ac5858be2614ed10ca47742c9522fd\/page&path=24.jpg",
        ".\/api\/archives\/28697b96f0ac5858be2614ed10ca47742c9522fd\/page&path=25.jpg",
        ".\/api\/archives\/28697b96f0ac5858be2614ed10ca47742c9522fd\/page&path=26.jpg",
        ".\/api\/archives\/28697b96f0ac5858be2614ed10ca47742c9522fd\/page&path=27.jpg",
        ".\/api\/archives\/28697b96f0ac5858be2614ed10ca47742c9522fd\/page&path=28.jpg",
        ".\/api\/archives\/28697b96f0ac5858be2614ed10ca47742c9522fd\/page&path=29.jpg",
        ".\/api\/archives\/28697b96f0ac5858be2614ed10ca47742c9522fd\/page&path=30.jpg",
        ".\/api\/archives\/28697b96f0ac5858be2614ed10ca47742c9522fd\/page&path=31.jpg",
        ".\/api\/archives\/28697b96f0ac5858be2614ed10ca47742c9522fd\/page&path=32.jpg",
        ".\/api\/archives\/28697b96f0ac5858be2614ed10ca47742c9522fd\/page&path=33.jpg",
        ".\/api\/archives\/28697b96f0ac5858be2614ed10ca47742c9522fd\/page&path=34.jpg",
        ".\/api\/archives\/28697b96f0ac5858be2614ed10ca47742c9522fd\/page&path=35.jpg",
        ".\/api\/archives\/28697b96f0ac5858be2614ed10ca47742c9522fd\/page&path=36.jpg",
        ".\/api\/archives\/28697b96f0ac5858be2614ed10ca47742c9522fd\/page&path=37.jpg",
        ".\/api\/archives\/28697b96f0ac5858be2614ed10ca47742c9522fd\/page&path=38.jpg",
        ".\/api\/archives\/28697b96f0ac5858be2614ed10ca47742c9522fd\/page&path=39.jpg",
        ".\/api\/archives\/28697b96f0ac5858be2614ed10ca47742c9522fd\/page&path=40.jpg"
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
    "operation": "______"
    "error": "No archive ID specified."
    "status": 0
}
```

{% endapi-method-response-example %}
{% endapi-method-response %}
{% endapi-method-spec %}
{% endapi-method %}

{% api-method method="delete" host="http://lrr.tvc-16.science" path="/api/archives/:id/isnew" %}
{% api-method-summary %}
Clear Archive New flag 
{% endapi-method-summary %}

{% api-method-description %}
Clears the "New!" flag on an archive.
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}
{% api-method-path-parameters %}
{% api-method-parameter name="id" type="string" required=true %}
ID of the Archive to process
{% endapi-method-parameter %}
{% endapi-method-path-parameters %}
{% endapi-method-request %}

{% api-method-response %}
{% api-method-response-example httpCode=200 %}
{% api-method-response-example-description %}
New flag is successfully removed
{% endapi-method-response-example-description %}

```javascript
{
    "id": "f3fc480a97f1afcd81c8e3392a3bcc66fe6c0809",
    "operation": "clear_new",
    "success": 1
}
```

{% endapi-method-response-example %}
{% endapi-method-response %}
{% endapi-method-spec %}
{% endapi-method %}

{% api-method method="put" host="http://lrr.tvc-16.science" path="/api/archives/:id/progress/:page" %}
{% api-method-summary %}
Update Reading Progression 
{% endapi-method-summary %}

{% api-method-description %}
Tell the server which page of this Archive you're currently showing/reading, so that it updates its internal reading progression accordingly.  
You should call this endpoint only when you're sure the user is currently reading the page you present.  
**Don't** use it when preloading images off the server.  

Whether to make reading progression regressible or not is up to the client. (The web client will reduce progression if the user starts reading previous pages)  
Consider however removing the "New!" flag from an archive when you start updating its progress - The web client won't display any reading progression if the new flag is still set.  

{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}
{% api-method-path-parameters %}
{% api-method-parameter name="id" type="string" required=true %}
ID of the Archive to process
{% endapi-method-parameter %}
{% api-method-parameter name="page" type="int" required=true %}
Current page to update the reading progress to.  
**Must** be a positive integer, and inferior or equal to the total page number of the archive.
{% endapi-method-parameter %}
{% endapi-method-path-parameters %}
{% endapi-method-request %}

{% api-method-response %}
{% api-method-response-example httpCode=200 %}
{% api-method-response-example-description %}
Progression updated.
{% endapi-method-response-example-description %}

```javascript
{
  "id": "75d18ce470dc99f83dc355bdad66319d1f33c82b",
  "operation": "update_progress",
  "page": 34,
  "success": 1
}
```

{% endapi-method-response-example %}

{% api-method-response-example httpCode=400 %}
{% api-method-response-example-description %}
You didn't specify the id parameter, provided a bad progress value, or the server doesn't know how many pages the archive has yet.
{% endapi-method-response-example-description %}

```javascript
{
    "operation": "update_progress"
    "error": "No archive ID specified."
    "status": 0
}

{
    "error": "Invalid progress value.",
    "operation": "update_progress",
    "success": 0
}

{
    "error": "Archive doesn't have a total page count recorded yet.",
    "operation": "update_progress",
    "success": 0
}
```

{% endapi-method-response-example %}

{% endapi-method-response %}
{% endapi-method-spec %}
{% endapi-method %}

{% api-method method="put" host="http://lrr.tvc-16.science" path="/api/archives/:id/metadata" %}
{% api-method-summary %}
🔑Update Archive Metadata
{% endapi-method-summary %}

{% api-method-description %}
Update tags and title for the given Archive.  
Data supplied to the server through this method will **overwrite** the previous data.
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}
{% api-method-path-parameters %}
{% api-method-parameter name="id" type="string" required=true %}
ID of the Archive to process.
{% endapi-method-parameter %}
{% endapi-method-path-parameters %}

{% api-method-query-parameters %}
{% api-method-parameter name="title" type="string" required=false %}
New Title of the Archive.
{% endapi-method-parameter %}

{% api-method-parameter name="tags" type="string" required=false %}
New Tags of the Archive.
{% endapi-method-parameter %}
{% endapi-method-query-parameters %}

{% endapi-method-request %}

{% api-method-response %}
{% api-method-response-example httpCode=200 %}
{% api-method-response-example-description %}
Metadata is updated.  
{% endapi-method-response-example-description %}

```javascript
{
    "operation": "update_metadata"
    "status": 1
}
```

{% endapi-method-response-example %}

{% api-method-response-example httpCode=400 %}
{% api-method-response-example-description %}
You didn't specify the id parameter.
{% endapi-method-response-example-description %}

```javascript
{
    "operation": "______"
    "error": "No archive ID specified."
    "status": 0
}
```

{% endapi-method-response-example %}
{% endapi-method-response %}
{% endapi-method-spec %}
{% endapi-method %}
