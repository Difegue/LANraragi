---
description: Query and modify the database.
---

# Database API

{% api-method method="get" host="http://lrr.tvc-16.science" path="/api/database/stats" %}
{% api-method-summary %}
Get Statistics
{% endapi-method-summary %}

{% api-method-description %}
Get tags from in the database, in order of importance.
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}

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
{% endapi-method-response %}
{% endapi-method-spec %}
{% endapi-method %}

{% api-method method="post" host="http://lrr.tvc-16.science" path="/api/database/clean" %}
{% api-method-summary %}
🔑Clean the Database
{% endapi-method-summary %}

{% api-method-description %}
Cleans the Database, removing entries for files that are no longer on the filesystem.
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}

{% api-method-response %}
{% api-method-response-example httpCode=200 %}
{% api-method-response-example-description %}
The database is cleaned, and the API returns how many items were removed.
{% endapi-method-response-example-description %}

```javascript
{
  "operation": "clean_database",
  "success": 1,
  "total": 0
}
```
{% endapi-method-response-example %}
{% endapi-method-response %}
{% endapi-method-spec %}
{% endapi-method %}

{% api-method method="post" host="http://lrr.tvc-16.science" path="/api/database/drop" %}
{% api-method-summary %}
🔑Drop the Database
{% endapi-method-summary %}

{% api-method-description %}
Delete the entire database, including user preferences.  
This is a rather dangerous endpoint, invoking it might lock you out of the server as a client!
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}

{% api-method-response %}
{% api-method-response-example httpCode=200 %}
{% api-method-response-example-description %}
LIVING IN THE DA  
TA  
BASE  
WOW WOW
{% endapi-method-response-example-description %}

```javascript
{
    "operation":"drop_database",
    "success":1
}
```
{% endapi-method-response-example %}
{% endapi-method-response %}
{% endapi-method-spec %}
{% endapi-method %}

{% api-method method="get" host="http://lrr.tvc-16.science" path="/api/database/backup" %}
{% api-method-summary %}
🔑Get a backup JSON
{% endapi-method-summary %}

{% api-method-description %}
Scans the entire database and returns a backup in JSON form.   
This backup can be reimported manually through the Backup and Restore feature.
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}

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
{% endapi-method-response %}
{% endapi-method-spec %}
{% endapi-method %}

{% api-method method="delete" host="http://lrr.tvc-16.science" path="/api/database/isnew" %}
{% api-method-summary %}
🔑Clear all "New" flags
{% endapi-method-summary %}

{% api-method-description %}
Clears the "New!" flag on all archives.
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}

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
{% endapi-method-response %}
{% endapi-method-spec %}
{% endapi-method %}

