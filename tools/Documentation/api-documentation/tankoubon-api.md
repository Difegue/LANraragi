# Tankoubon API

{% swagger baseUrl="http://lrr.tvc-16.science" path="/api/tankoubons" method="get" summary="Get all tankoubons" %}
{% swagger-description %}
Get list of Tankoubons paginated.
{% endswagger-description %}

{% swagger-parameter name="page" type="string" required="false" in="query" %}
Page of the list of Tankoubons.
{% endswagger-parameter %}

{% swagger-response status="200" description="" %}
```javascript
{
    "filtered": 2,
    "result": [
        {
            "archives": [
                "28697b96f0ac5858be2614ed10ca47742c9522fd",
                "4857fd2e7c00db8b0af0337b94055d8445118630",
                "fa74bc15e7dd2b6ec0dc2e10cc7cd4942867318a"
            ],
            "id": "TANK_1688616437",
            "name": "Test 1",
            "summary": "",
            "tags": ""
        },
        {
            "archives": [
                "fa74bc15e7dd2b6ec0dc2e10cc7cd4942867318a"
            ],
            "id": "TANK_1688693913",
            "name": "Test 2",
            "summary": "",
            "tags": ""
        }
    ],
    "total": 2
}
```
{% endswagger-response %}
{% endswagger %}

{% swagger baseUrl="http://lrr.tvc-16.science" path="/api/tankoubons/:id" method="get" summary="Get a single tankoubon" %}
{% swagger-description %}
Get the details of the specified tankoubon ID, with the archives list paginated.
{% endswagger-description %}

{% swagger-parameter name="id" type="string" required="true" in="path" %}
ID of the Tankoubon desired.
{% endswagger-parameter %}

{% swagger-parameter name="include_full_data" type="string" required="false" in="query" %}
If set in 1, it appends a full_data array with Archive objects.
{% endswagger-parameter %}

{% swagger-parameter name="page" type="string" required="false" in="query" %}
Page of the Archives list.
{% endswagger-parameter %}

{% swagger-response status="200" description="include_full_data = 0" %}
```javascript
{
    "filtered": 3,
    "result": {
        "archives": [
            "fa74bc15e7dd2b6ec0dc2e10cc7cd4942867318a",
            "28697b96f0ac5858be2614ed10ca47742c9522fd",
            "4857fd2e7c00db8b0af0337b94055d8445118630"
        ],
        "id": "TANK_1688616437",
        "name": "Test 1",
        "summary": "",
        "tags": ""
    },
    "total": 3
}
```
{% endswagger-response %}

{% swagger-response status="200" description="include_full_data = 1" %}
```javascript
{
    "filtered": 3,
    "result": {
        "archives": [
            "fa74bc15e7dd2b6ec0dc2e10cc7cd4942867318a",
            "28697b96f0ac5858be2614ed10ca47742c9522fd",
            "4857fd2e7c00db8b0af0337b94055d8445118630"
        ],
        "full_data": [
            {
                "arcid": "fa74bc15e7dd2b6ec0dc2e10cc7cd4942867318a",
                "extension": "zip",
                "isnew": "true",
                "lastreadtime": 0,
                "pagecount": 30,
                "progress": 0,
                "tags": "date_added:1688608157",
                "lastreadtime": 0,
                "title": "(C95) [wadamemo (WADA Rco)] Fate GO MEMO 3 (Fate Grand Order)"
            },
            {
                "arcid": "28697b96f0ac5858be2614ed10ca47742c9522fd",
                "extension": "zip",
                "isnew": "true",
                "lastreadtime": 0,
                "pagecount": 30,
                "progress": 0,
                "tags": "date_added:1688608157",
                "lastreadtime": 0,
                "title": "FateGOMEMO"
            },
            {
                "arcid": "4857fd2e7c00db8b0af0337b94055d8445118630",
                "extension": "zip",
                "isnew": "true",
                "lastreadtime": 0,
                "pagecount": 26,
                "progress": 0,
                "tags": "date_added:1688608157",
                "lastreadtime": 0,
                "title": "gits (2)"
            }
        ],
        "id": "TANK_1688616437",
        "name": "Test 1",
        "summary": "",
        "tags": ""
    },
    "total": 3
}
```
{% endswagger-response %}

{% swagger-response status="400" description="" %}
```javascript
{
  "error": "The given tankoubon does not exist.",
  "operation": "get_tankoubon",
  "success": 0
}
```
{% endswagger-response %}
{% endswagger %}

{% swagger baseUrl="http://lrr.tvc-16.science" path="/api/tankoubons" method="put" summary="🔑Create a Tankoubon" %}
{% swagger-description %}
Create a new Tankoubon or updated the name of an existing one.
{% endswagger-description %}

{% swagger-parameter name="name" type="string" required="true" in="query" %}
Name of the Category.
{% endswagger-parameter %}

{% swagger-response status="200" description="" %}
```javascript
{
    "operation": "create_tankoubon",
    "success": 1,
    "tankoubon_id": "TANK_1690056313"
}
```
{% endswagger-response %}

{% swagger-response status="400" description="" %}
```javascript
{
  "error": "Tankoubon name not specified.",
  "operation": "create_tankoubon",
  "success": 0
}
```
{% endswagger-response %}
{% endswagger %}

{% swagger baseUrl="http://lrr.tvc-16.science" path="/api/tankoubons/:id" method="put" summary="🔑Update a Tankoubon" %}
{% swagger-description %}
Update a Tankoubon.
{% endswagger-description %}

{% swagger-parameter name="id" type="string" required="true" in="path" %}
ID of the Tankoubon to update.
{% endswagger-parameter %}

{% swagger-parameter name="archives" type="json" required="true" in="body" %}
Json with 2 optional keys "archives" and "metadata" defining:

- archives: Ordered array with the IDs of the archives.
- metadata: Json with the metadata parameters: name, summary, tags.

Note: If there is no need to update something in one of the keys, do not send the key, otherwise can result on unwanted results.
{% endswagger-parameter %}

{% swagger-response status="200" description="" %}
```javascript
{
    "error": "",
    "operation": "update_tankoubon",
    "success": 1,
    "successMessage": "Updated tankoubon \"Test 1\"!"
}
```
{% endswagger-response %}

{% swagger-response status="400" description="" %}
```javascript
{
  "error": "rr doesn't exist in the database!",
  "operation": "update_tankoubon",
  "success": 0
}
```
{% endswagger-response %}
{% endswagger %}

{% swagger baseUrl="http://lrr.tvc-16.science" path="/api/tankoubons/:id/:archive" method="put" summary="🔑Add an archive to a Tankoubon" %}
{% swagger-description %}
Append an archive at the final position of a Tankoubon.
{% endswagger-description %}

{% swagger-parameter name="id" type="string" required="true" in="path" %}
ID of the Tankoubon to update.
{% endswagger-parameter %}

{% swagger-parameter name="archive" type="string" required="true" in="path" %}
ID of the Archive to append.
{% endswagger-parameter %}

{% swagger-response status="200" description="" %}
```javascript
{
    "error": "",
    "operation": "add_to_tankoubon",
    "success": 1,
    "successMessage": "Added \"(C95) [wadamemo (WADA Rco)] Fate GO MEMO 3 (Fate Grand Order)\" to tankoubon \"Test 1\"!"
}
```
{% endswagger-response %}

{% swagger-response status="400" description="" %}
```javascript
{
  "error": "rr doesn't exist in the database!",
  "operation": "add_to_tankoubon",
  "success": 0
}
```
{% endswagger-response %}
{% endswagger %}

{% swagger baseUrl="http://lrr.tvc-16.science" path="/api/tankoubons/:id/:archive" method="delete" summary="🔑Remove an archive from a Tankoubon" %}
{% swagger-description %}
Remove an archive from a Tankoubon.
{% endswagger-description %}

{% swagger-parameter name="id" type="string" required="true" in="path" %}
ID of the Tankoubon to update.
{% endswagger-parameter %}

{% swagger-parameter name="archive" type="string" required="true" in="path" %}
ID of the archive to remove.
{% endswagger-parameter %}

{% swagger-response status="200" description="" %}
```javascript
{
    "error": "",
    "operation": "remove_from_tankoubon",
    "success": 1,
    "successMessage": "Removed \"(C95) [wadamemo (WADA Rco)] Fate GO MEMO 3 (Fate Grand Order)\" from tankoubon \"Test 1\"!"
}
```
{% endswagger-response %}

{% swagger-response status="400" description="" %}
```javascript
{
  "error": "rr doesn't exist in the database!",
  "operation": "remove_from_tankoubon",
  "success": 0
}
```
{% endswagger-response %}
{% endswagger %}

{% swagger baseUrl="http://lrr.tvc-16.science" path="/api/tankoubons/:id" method="delete" summary="🔑Delete a Tankoubon" %}
{% swagger-description %}
Remove a Tankoubon.
{% endswagger-description %}

{% swagger-parameter name="id" type="string" required="true" in="path" %}
ID of the Tankoubon to delete.
{% endswagger-parameter %}

{% swagger-response status="200" description="" %}
```javascript
{
    "error": "",
    "operation": "delete_tankoubon",
    "success": 1,
    "successMessage": null
}
```
{% endswagger-response %}
{% endswagger %}
