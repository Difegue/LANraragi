---
description: >-
  The Client API allows you to communicate with a running LANraragi instance
  from another client, for instance. All those endpoints can be tested on the
  demo!
---

# Client API

## About the API Key

While most API endpoints here are public, a few require a form of authentication. Said authentication is provided by a configurable **API Key**. This key will have to be added to the API calls with the _key_ parameter.

{% hint style="warning" %}
If your LRR installation is running under **No-Fun Mode**, all API methods will be locked behind the key.  
Empty API Keys will **not** work, even if there's no key set in Configuration.
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
    "isnew": "true",
    "tags": "",
    "title": "Ghost in the Shell 01.5 - Human-Error Processor v01c01"
}, {
    "arcid": "28697b96f0ac5858be2614ed10ca47742c9522fd",
    "isnew": "false",
    "tags": "parody:fate grand order,  group:wadamemo,  artist:wada rco,  artbook,  full color",
    "title": "Fate GO MEMO"
}, {
    "arcid": "2810d5e0a8d027ecefebca6237031a0fa7b91eb3",
    "isnew": "false",
    "tags": "parody:fate grand order,  character:abigail williams,  character:artoria pendragon alter,  character:asterios,  character:ereshkigal,  character:gilgamesh,  character:hans christian andersen,  character:hassan of serenity,  character:hector,  character:helena blavatsky,  character:irisviel von einzbern,  character:jeanne alter,  character:jeanne darc,  character:kiara sessyoin,  character:kiyohime,  character:lancer,  character:martha,  character:minamoto no raikou,  character:mochizuki chiyome,  character:mordred pendragon,  character:nitocris,  character:oda nobunaga,  character:osakabehime,  character:penthesilea,  character:queen of sheba,  character:rin tosaka,  character:saber,  character:sakata kintoki,  character:scheherazade,  character:sherlock holmes,  character:suzuka gozen,  character:tamamo no mae,  character:ushiwakamaru,  character:waver velvet,  character:xuanzang,  character:zhuge liang,  group:wadamemo,  artist:wada rco,  artbook,  full color",
    "title": "Fate GO MEMO 2"
}, {
    "arcid": "e69e43e1355267f7d32a4f9b7f2fe108d2401ebf",
    "isnew": "false",
    "tags": "character:segata sanshiro",
    "title": "Saturn Backup Cartridge - Japanese Manual"
}, {
    "arcid": "e4c422fd10943dc169e3489a38cdbf57101a5f7e",
    "isnew": "false",
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

{% api-method method="get" host="http://lrr.tvc-16.science" path="/api/opds" %}
{% api-method-summary %}
Get the Archive Index (OPDS Edition)
{% endapi-method-summary %}

{% api-method-description %}
Get the Archive Index as an [OPDS 1.2](https://specs.opds.io/opds-1.2) Catalog.
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}
{% api-method-path-parameters %}
{% api-method-parameter name="id" type="string" required=false %}
ID of an archive. Passing this will show only one \<entry\> for the given ID in the result, instead of all the archives.
{% endapi-method-parameter %}
{% api-method-parameter name="key" type="string" required=false %}
API Key if needed.
{% endapi-method-parameter %}
{% endapi-method-path-parameters %}
{% endapi-method-request %}

{% api-method-response %}
{% api-method-response-example httpCode=200 %}
{% api-method-response-example-description %}
The OPDS Catalog is generated. This API is mostly meant to be used as-is by external software implementing the spec.
{% endapi-method-response-example-description %}

```xml

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


{% api-method method="get" host="http://lrr.tvc-16.science" path="/api/search" %}
{% api-method-summary %}
Search the Archive Index
{% endapi-method-summary %}

{% api-method-description %}
Search for Archives. You can use the IDs of this JSON with the other endpoints.
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}
{% api-method-path-parameters %}
{% api-method-parameter name="key" type="string" required=false %}
API Key if needed.
{% endapi-method-parameter %}

{% api-method-parameter name="filter" type="string" required=false %}
Search query. You can use the following special characters in it:  
**Quotation Marks \("..."\)**  
Exact string search. Allows a search term to include spaces. Everything placed inside a pair of quotation marks is treated as a singular term. Wildcard characters are still interpreted as wildcards.  
  
**Question Mark \(?\), Underscore \(\_\)**  
Wildcard. Can match any single character.  
  
**Asterisk \(\*\), Percentage Sign \(%\)**  
Wildcard. Can match any sequence of characters \(including none\).  
  
**Subtraction Sign \(-\)**  
Exclusion. When placed before a term, prevents search results from including that term.  
  
**Dollar Sign \($\)**  
Add at the end of a tag to perform an exact tag search rather than displaying all elements that start with the term. Only matches tags regardless of search parameters and can be used as an exclusion to ignore misc tags in the search query.
{% endapi-method-parameter %}

{% api-method-parameter name="start" type="string" required=false %}
From which archive in the total result count this enumeration should start. The total number of archives displayed depends on the server-side _page size_ preference.
{% endapi-method-parameter %}

{% api-method-parameter name="sortby" type="string" required=false %}
Namespace by which you want to sort the results, or _title_ if you want to sort by title. \(Default value is title.\)
{% endapi-method-parameter %}

{% api-method-parameter name="order" type="string" required=false %}
Order of the sort, either `asc` or `desc`.
{% endapi-method-parameter %}

{% api-method-parameter name="newonly" type="boolean" required=false %}
Set to `true` to only show new archives.
{% endapi-method-parameter %}

{% endapi-method-path-parameters %}
{% endapi-method-request %}

{% api-method-response %}
{% api-method-response-example httpCode=200 %}
{% api-method-response-example-description %}
Search is performed.
{% endapi-method-response-example-description %}

```javascript

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
You get the image directly.
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

{% api-method method="get" host="http://lrr.tvc-16.science" path="/api/tagstats" %}
{% api-method-summary %}
Get Tag statistics
{% endapi-method-summary %}

{% api-method-description %}
Get tags from in the database, in order of importance.
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}
{% api-method-path-parameters %}
{% api-method-parameter name="key" type="string" required=false %}
API Key, if needed.
{% endapi-method-parameter %}
{% endapi-method-path-parameters %}
{% endapi-method-request %}

{% api-method-response %}
{% api-method-response-example httpCode=200 %}
{% api-method-response-example-description %}
JSON Array of {tag; weight} objects. Higher weight = Tag is more prevalent in the DB.
{% endapi-method-response-example-description %}

```javascript
[
    {"namespace":"character","text":"jeanne alter","weight":2},
    {"namespace":"character","text":"xuanzang","weight":1},
    {"namespace":"artist","text":"wada rco","weight":2},
    {"namespace":"parody","text":"fate grand order","weight":3},
    {"namespace":"group","text":"wadamemo","weight":2},
    {"namespace":"","text":"artbook","weight":2},
]
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

{% api-method method="get" host="http://lrr.tvc-16.science" path="/api/untagged" %}
{% api-method-summary %}
Get Untagged archives
{% endapi-method-summary %}

{% api-method-description %}
Get archives that don't have any tags recorded. This follows the same rules as the Batch tagging filter and will include archives that have parody:, series: or artist: tags.
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}
{% api-method-path-parameters %}
{% api-method-parameter name="key" type="string" required=false %}
API Key, if needed.
{% endapi-method-parameter %}
{% endapi-method-path-parameters %}
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

{% api-method method="get" host="http://lrr.tvc-16.science" path="/api/clear\_new" %}
{% api-method-summary %}
Clear New flag on archive
{% endapi-method-summary %}

{% api-method-description %}
Clears the "New!" flag on an archive if an ID is provided. Otherwise, clears the flag on all archives.
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}
{% api-method-path-parameters %}
{% api-method-parameter name="key" type="string" required=false %}
API Key, if needed.
{% endapi-method-parameter %}

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
    "id":"f3fc480a97f1afcd81c8e3392a3bcc66fe6c0809",
    "operation":"clear_new",
    "success":1
}
```
{% endapi-method-response-example %}

{% api-method-response-example httpCode=401 %}
{% api-method-response-example-description %}
You didn't specify an API Key.
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

{% api-method method="get" host="http://lrr.tvc-16.science" path="/api/clear\_new\_all" %}
{% api-method-summary %}
Clear all New flags
{% endapi-method-summary %}

{% api-method-description %}
Clears the "New!" flag on all archives.
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}
{% api-method-path-parameters %}
{% api-method-parameter name="key" type="string" required=true %}
API Key, mandatory for this method.
{% endapi-method-parameter %}
{% endapi-method-path-parameters %}
{% endapi-method-request %}

{% api-method-response %}
{% api-method-response-example httpCode=200 %}
{% api-method-response-example-description %}
New flags are successfully removed
{% endapi-method-response-example-description %}

```javascript
{
    "operation":"clear_new_all",
    "success":1
}
```
{% endapi-method-response-example %}

{% api-method-response-example httpCode=401 %}
{% api-method-response-example-description %}
You didn't specify an API Key.
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

{% api-method method="get" host="http://lrr.tvc-16.science" path="/api/stop\_shinobu" %}
{% api-method-summary %}
Stop Background Worker
{% endapi-method-summary %}

{% api-method-description %}
Stops the Shinobu Background Worker. If you want to restart it, use the `/api/restart_shinobu` endpoint instead.
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}
{% api-method-path-parameters %}
{% api-method-parameter name="key" type="string" required=true %}
API Key, mandatory for this method.
{% endapi-method-parameter %}
{% endapi-method-path-parameters %}
{% endapi-method-request %}

{% api-method-response %}
{% api-method-response-example httpCode=200 %}
{% api-method-response-example-description %}
Shinobu is successfully stopped.
{% endapi-method-response-example-description %}

```javascript
{
    "operation":"shinobu_stop",
    "success":1
}
```
{% endapi-method-response-example %}

{% api-method-response-example httpCode=401 %}
{% api-method-response-example-description %}
You didn't specify an API Key.
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

{% api-method method="get" host="http://lrr.tvc-16.science" path="/api/backup" %}
{% api-method-summary %}
Print a backup JSON
{% endapi-method-summary %}

{% api-method-description %}
Scans the entire database and returns a backup in JSON form. This backup can be reimported manually through the Backup and Restore feature.
{% page-ref page="advanced-usage/backup-and-restore.md" %}
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}
{% api-method-path-parameters %}
{% api-method-parameter name="key" type="string" required=true %}
API Key, mandatory for this method.
{% endapi-method-parameter %}
{% endapi-method-path-parameters %}
{% endapi-method-request %}

{% api-method-response %}
{% api-method-response-example httpCode=200 %}
{% api-method-response-example-description %}
Prints a backup JSON.
{% endapi-method-response-example-description %}

```javascript
[
    {
        "arcid": "e4c422fd10943dc169e3489a38cdbf57101a5f7e",
        "title": "rohan",
        "tags": "language:english, parody:jojos bizarre adventure, character:rohan kishibe, date_added:1541778455",
        "thumbhash": "f0a335a3562da03b61d69242b9562592eade06b9",
        "filename": "rohan"
    },
    {
        "arcid": "e69e43e1355267f7d32a4f9b7f2fe108d2401ebf",
        "title": "saturn",
        "tags": " language:english, parody:sailor moon, character:sailor saturn, date_added:1553537268",
        "thumbhash": "631fb75a5aed97ee977783472e7d6b093c6df87d",
        "filename": "saturn"
    },
    {
        "arcid": "d1858d5dc36925aa66be072a97817650d39de166",
        "title": "test title",
        "tags": "",
        "thumbhash": "9846bb6d62949b56545c42e88d8010446b65702e",
        "filename": "[Memes]9B789D38B0784C5FBC9D59A9F24D20F2"
    },
    {
        "arcid": "28697b96f0ac5858be2614ed10ca47742c9522fd",
        "title": "Fate GO MEMO",
        "tags": "parody:fate grand order, group:wadamemo, artist:wada rco, artbook, full color, super:test, date_added:1553537258",
        "thumbhash": "ec2a0ca3a3da67a9390889f0910fe494241faa9a",
        "filename": "FateGOMEMO"
    }
]
```
{% endapi-method-response-example %}

{% api-method-response-example httpCode=401 %}
{% api-method-response-example-description %}
You didn't specify an API Key.
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

