---
description: Everything dealing with Archives.
---

# Archive API

{% swagger baseUrl="http://lrr.tvc-16.science" path="/api/archives" method="get" summary="Get all Archives" %}
{% swagger-description %}
Get the Archive Index in JSON form. You can use the IDs of this JSON with the other endpoints.
{% endswagger-description %}

{% swagger-response status="200" description="" %}
```javascript
[{
    "arcid": "ec9b83b6a835771b0f9862d0326add2f8373989a",
    "isnew": "true",
    "extension": "zip",
    "pagecount": 128,
    "progress": 0,
    "tags": "",
    "title": "Ghost in the Shell 01.5 - Human-Error Processor v01c01"
}, {
    "arcid": "28697b96f0ac5858be2614ed10ca47742c9522fd",
    "isnew": "false",
    "extension": "rar",
    "pagecount": 34,
    "progress": 3,
    "tags": "parody:fate grand order,  group:wadamemo,  artist:wada rco,  artbook,  full color",
    "title": "Fate GO MEMO"
}, {
    "arcid": "2810d5e0a8d027ecefebca6237031a0fa7b91eb3",
    "isnew": "false",
    "extension": "cbz",
    "pagecount": 0,
    "progress": 0,
    "tags": "parody:fate grand order,  character:abigail williams,  character:artoria pendragon alter,  character:asterios,  character:ereshkigal,  character:gilgamesh,  character:hans christian andersen,  character:hassan of serenity,  character:hector,  character:helena blavatsky,  character:irisviel von einzbern,  character:jeanne alter,  character:jeanne darc,  character:kiara sessyoin,  character:kiyohime,  character:lancer,  character:martha,  character:minamoto no raikou,  character:mochizuki chiyome,  character:mordred pendragon,  character:nitocris,  character:oda nobunaga,  character:osakabehime,  character:penthesilea,  character:queen of sheba,  character:rin tosaka,  character:saber,  character:sakata kintoki,  character:scheherazade,  character:sherlock holmes,  character:suzuka gozen,  character:tamamo no mae,  character:ushiwakamaru,  character:waver velvet,  character:xuanzang,  character:zhuge liang,  group:wadamemo,  artist:wada rco,  artbook,  full color",
    "title": "Fate GO MEMO 2"
}, {
    "arcid": "e69e43e1355267f7d32a4f9b7f2fe108d2401ebf",
    "isnew": "false",
    "extension": "pdf",
    "pagecount": 0,
    "progress": 0,
    "tags": "character:segata sanshiro",
    "title": "Saturn Backup Cartridge - Japanese Manual"
}, {
    "arcid": "e4c422fd10943dc169e3489a38cdbf57101a5f7e",
    "isnew": "false",
    "extension": "epub",
    "pagecount": 0,
    "progress": 0,
    "tags": "parody: jojo's bizarre adventure",
    "title": "Rohan Kishibe goes to Gucci"
}]
```
{% endswagger-response %}
{% endswagger %}

{% swagger baseUrl="http://lrr.tvc-16.science" path="/api/archives/untagged" method="get" summary="Get Untagged Archives" %}
{% swagger-description %}
Get archives that don't have any tags recorded. This follows the same rules as the Batch Tagging filter and will include archives that have parody:, date_added:, series: or artist: tags.
{% endswagger-description %}

{% swagger-response status="200" description="" %}
```javascript
[
    "d1858d5dc36925aa66be072a97817650d39de166",
    "c3458d5dc36925da93be072a97817650d39de166",
    "28697b96f0ac5858be2614ed10ca47742c9522fd",
]
```
{% endswagger-response %}
{% endswagger %}

{% swagger baseUrl="http://lrr.tvc-16.science" path="/api/archives/:id/metadata" method="get" summary="Get Archive Metadata" %}
{% swagger-description %}
Get Metadata (title, tags) for a given Archive.
{% endswagger-description %}

{% swagger-parameter name="id" type="string" required="true" in="path" %}
ID of the Archive to process.
{% endswagger-parameter %}

{% swagger-response status="200" description="" %}
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
{% endswagger-response %}

{% swagger-response status="400" description="" %}
```javascript
{
    "operation": "______",
    "error": "No archive ID specified.",
    "success": 0
}
```
{% endswagger-response %}
{% endswagger %}

{% swagger baseUrl="http://lrr.tvc-16.science" path="/api/archives/:id/categories" method="get" summary="Get Archive Categories" %}
{% swagger-description %}
Get all the Categories which currently refer to this Archive ID.
{% endswagger-description %}

{% swagger-parameter name="id" type="string" required="true" in="path" %}
ID of the Archive to process.
{% endswagger-parameter %}

{% swagger-response status="200" description="" %}
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
{% endswagger-response %}

{% swagger-response status="400" description="" %}
```javascript
{
    "operation": "______",
    "error": "No archive ID specified.",
    "success": 0
}
```
{% endswagger-response %}
{% endswagger %}

{% swagger baseUrl="http://lrr.tvc-16.science" path="/api/archives/:id/thumbnail" method="get" summary="Get Archive Thumbnail" %}
{% swagger-description %}
Get the Thumbnail image for a given Archive. This endpoint will queue generation of the thumbnail in the background if it doesn't already exist, and return a placeholder image.  
If you want to get the background job ID instead of the placeholder, you can use the `no_fallback` query parameter.
{% endswagger-description %}

{% swagger-parameter name="id" type="string" required="true" in="path" %}
ID of the Archive to process.
{% endswagger-parameter %}
{% swagger-parameter name="no_fallback" type="boolean" required="false" in="query" %}
Disables the placeholder image and returns a JSON if the thumbnail is queued for extraction. This parameter does nothing if the image already exists.
{% endswagger-parameter %}

{% swagger-response status="202" description="The thumbnail is queued for extraction. Use `/api/minion/:jobid` to track when your thumbnail is ready." %}
```javascript
{
    "operation": "______",
    "error": "No archive ID specified.",
    "success": 0
}
```
{% endswagger-response %}

{% swagger-response status="200" description="" %}
{% tabs %}
{% tab title="2810d5e0a8d027ecefebca6237031a0fa7b91eb3.jpg" %}
```
```
{% endtab %}
{% endtabs %}
{% endswagger-response %}

{% swagger-response status="400" description="" %}
```javascript
{
    "operation": "______",
    "error": "No archive ID specified.",
    "success": 0
}
```
{% endswagger-response %}
{% endswagger %}

{% swagger baseUrl="http://lrr.tvc-16.science" path="/api/archives/:id/download" method="get" summary="Download an Archive" %}
{% swagger-description %}
Download an Archive from the server.
{% endswagger-description %}

{% swagger-parameter name="id" type="string" required="true" in="path" %}
ID of the Archive to download.
{% endswagger-parameter %}

{% swagger-response status="200" description="" %}
{% tabs %}
{% tab title="Archive.zip" %}
```
```
{% endtab %}
{% endtabs %}
{% endswagger-response %}

{% swagger-response status="400" description="" %}
```javascript
{
    "operation": "______",
    "error": "No archive ID specified.",
    "success": 0
}
```
{% endswagger-response %}
{% endswagger %}

{% swagger baseUrl="http://lrr.tvc-16.science" path="/api/archives/:id/files" method="get" summary="Extract an Archive" %}
{% swagger-description %}
Get a list of URLs pointing to the images contained in an archive. If necessary, this endpoint also launches a background Minion job to extract the archive so it is ready for reading.
{% endswagger-description %}

{% swagger-parameter name="id" type="string" required="true" in="path" %}
ID of the Archive to process.
{% endswagger-parameter %}

{% swagger-parameter name="force" type="bool" required="false" in="query" %}
Force a full background re-extraction of the Archive.  
Existing cached files might still be used in subsequent `/api/archives/:id/page` calls until the Archive is fully re-extracted.
{% endswagger-parameter %}

{% swagger-response status="200" description="" %}
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
{% endswagger-response %}

{% swagger-response status="400" description="" %}
```javascript
{
    "operation": "get_file_list",
    "error": "No archive ID specified.",
    "success": 0
}
```
{% endswagger-response %}
{% endswagger %}

{% swagger baseUrl="http://lrr.tvc-16.science" path="/api/archives/:id/isnew" method="delete" summary="Clear Archive New flag" %}
{% swagger-description %}
Clears the "New!" flag on an archive.
{% endswagger-description %}

{% swagger-parameter name="id" type="string" required="true" in="path" %}
ID of the Archive to process
{% endswagger-parameter %}

{% swagger-response status="200" description="" %}
```javascript
{
    "id": "f3fc480a97f1afcd81c8e3392a3bcc66fe6c0809",
    "operation": "clear_new",
    "success": 1
}
```
{% endswagger-response %}
{% endswagger %}

{% swagger baseUrl="http://lrr.tvc-16.science" path="/api/archives/:id/progress/:page" method="put" summary="Update Reading Progression" %}
{% swagger-description %}
Tell the server which page of this Archive you're currently showing/reading, so that it updates its internal reading progression accordingly.  
You should call this endpoint only when you're sure the user is currently reading the page you present.  
**Don't** use it when preloading images off the server.

Whether to make reading progression regressible or not is up to the client. (The web client will reduce progression if the user starts reading previous pages)  
Consider however removing the "New!" flag from an archive when you start updating its progress - The web client won't display any reading progression if the new flag is still set.

⚠ If the server is configured to use clientside progress tracking, this API call will return an error!  
Make sure to check using `/api/info` whether the server tracks reading progression or not before calling this endpoint.
{% endswagger-description %}

{% swagger-parameter name="id" type="string" required="true" in="path" %}
ID of the Archive to process
{% endswagger-parameter %}

{% swagger-parameter name="page" type="int" required="true" in="path" %}
Current page to update the reading progress to. **Must** be a positive integer, and inferior or equal to the total page number of the archive.
{% endswagger-parameter %}

{% swagger-response status="200" description="" %}
```javascript
{
  "id": "75d18ce470dc99f83dc355bdad66319d1f33c82b",
  "operation": "update_progress",
  "page": 34,
  "success": 1
}
```
{% endswagger-response %}

{% swagger-response status="400" description="" %}
```javascript
{
    "operation": "update_progress",
    "error": "No archive ID specified.",
    "success": 0
}

{
    "operation": "update_progress",
    "error": "Server-side Progress Tracking is disabled on this instance.",
    "success": 0
}

{
    "operation": "update_progress",
    "error": "Invalid progress value.",
    "success": 0
}

{
    "operation": "update_progress",
    "error": "Archive doesn't have a total page count recorded yet.",
    "success": 0
}
```
{% endswagger-response %}
{% endswagger %}

{% swagger baseUrl="http://lrr.tvc-16.science" path="/api/archives/:id/metadata" method="put" summary="🔑Update Archive Metadata" %}
{% swagger-description %}
Update tags and title for the given Archive. Data supplied to the server through this method will **overwrite** the previous data.
{% endswagger-description %}

{% swagger-parameter name="id" type="string" required="true" in="path" %}
ID of the Archive to process.
{% endswagger-parameter %}

{% swagger-parameter name="title" type="string" required="false" in="query" %}
New Title of the Archive.
{% endswagger-parameter %}

{% swagger-parameter name="tags" type="string" required="false" in="query" %}
New Tags of the Archive.
{% endswagger-parameter %}

{% swagger-response status="200" description="" %}
```javascript
{
    "operation": "update_metadata",
    "success": 1
}
```
{% endswagger-response %}

{% swagger-response status="400" description="" %}
```javascript
{
    "operation": "______",
    "error": "No archive ID specified.",
    "success": 0
}
```
{% endswagger-response %}
{% endswagger %}

{% swagger baseUrl="http://lrr.tvc-16.science" path="/api/archives/:id" method="delete" summary="🔑Delete Archive" %}
{% swagger-description %}
Delete both the archive metadata and the file stored on the server.  
🙏 Please ask your user for confirmation before invoking this endpoint.
{% endswagger-description %}

{% swagger-parameter name="id" type="string" required="true" in="path" %}
ID of the Archive to process.
{% endswagger-parameter %}

{% swagger-response status="200" description="" %}
```javascript
{
    "operation": "delete_archive",
    "success": 1,
    "id": "75d18ce470dc99f83dc355bdad66319d1f33c82b",
    "filename": "big_chungus.zip"
}
```
{% endswagger-response %}

{% swagger-response status="400" description="" %}
```javascript
{
    "operation": "delete_archive",
    "error": "No archive ID specified.",
    "success": 0
}
```
{% endswagger-response %}
{% endswagger %}
