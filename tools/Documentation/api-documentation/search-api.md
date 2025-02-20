---
description: Perform searches.
---

# Search API

{% swagger baseUrl="http://lrr.tvc-16.science" path="/api/search" method="get" summary="Search the Archive Index" %}
{% swagger-description %}
Search for Archives. You can use the IDs of this JSON with the other endpoints.
{% endswagger-description %}

{% swagger-parameter name="category" type="string" required="false" in="query" %}
ID of the category you want to restrict this search to.
{% endswagger-parameter %}

{% swagger-parameter name="filter" type="string" required="false" in="query" %}
Search query. You can use the following special characters in it:  

**Quotation Marks ("...")**  
Exact string search. Allows a search term to include spaces. Everything placed inside a pair of quotation marks is treated as a singular term. Wildcard characters are still interpreted as wildcards.

**Question Mark (?), Underscore (_)**  
Wildcard. Can match any single character.

**Asterisk (*), Percentage Sign (%)**  
Wildcard. Can match any sequence of characters (including none).

**Subtraction Sign (-)**  
Exclusion. When placed before a term, prevents search results from including that term.

**Dollar Sign ($)**  
Add at the end of a tag to perform an exact tag search rather than displaying all elements that start with the term. Only matches tags regardless of search parameters and can be used as an exclusion to ignore misc tags in the search query.
{% endswagger-parameter %}

{% swagger-parameter name="start" type="string" required="false" in="query" %}
From which archive in the total result count this enumeration should start. The total number of archives displayed depends on the server-side _page size_ preference.  
From 0.8.2 onwards, you can use "-1" here to get the full, unpaged data.
{% endswagger-parameter %}

{% swagger-parameter name="sortby" type="string" required="false" in="query" %}
Namespace by which you want to sort the results. There are specific sort keys you can use:  
- _title_ if you want to sort by title  
- _lastread_ if you want to sort by last read time. (If **Server-side Progress Tracking** is enabled)   
(Default value is title. If you sort by lastread, IDs that have never been read will be removed from the search.)  
{% endswagger-parameter %}

{% swagger-parameter name="order" type="string" required="false" in="query" %}
Order of the sort, either `asc` or `desc`.
{% endswagger-parameter %}

{% swagger-parameter name="newonly" type="bool" required="false" in="query" %}
Limit search to new archives only.
{% endswagger-parameter %}

{% swagger-parameter name="untaggedonly" type="bool" required="false" in="query" %}
Limit search to untagged archives only.
{% endswagger-parameter %}

{% swagger-parameter name="groupby_tanks" type="bool" required="false" in="query" %}
Enable or disable Tankoubon grouping. Defaults to true.  
When enabled, Tankoubons will show in search results, replacing all the archive IDs they contain. 
{% endswagger-parameter %}

{% swagger-response status="200" description="" %}
```javascript
{
    "data": [{
        "arcid": "28697b96f0ac5858be2614ed10ca47742c9522fd",
        "isnew": "none",
        "extension": "zip",
        "tags": "parody:fate grand order,  group:wadamemo,  artist:wada rco,  artbook,  full color",
        "lastreadtime": 1337038234,
        "title": "Fate GO MEMO"
    }, {
        "arcid": "2810d5e0a8d027ecefebca6237031a0fa7b91eb3",
        "isnew": "none",
        "extension": "rar",
        "tags": "parody:fate grand order,  character:abigail williams,  character:artoria pendragon alter,  character:asterios,  character:ereshkigal,  character:gilgamesh,  character:hans christian andersen,  character:hassan of serenity,  character:hector,  character:helena blavatsky,  character:irisviel von einzbern,  character:jeanne alter,  character:jeanne darc,  character:kiara sessyoin,  character:kiyohime,  character:lancer,  character:martha,  character:minamoto no raikou,  character:mochizuki chiyome,  character:mordred pendragon,  character:nitocris,  character:oda nobunaga,  character:osakabehime,  character:penthesilea,  character:queen of sheba,  character:rin tosaka,  character:saber,  character:sakata kintoki,  character:scheherazade,  character:sherlock holmes,  character:suzuka gozen,  character:tamamo no mae,  character:ushiwakamaru,  character:waver velvet,  character:xuanzang,  character:zhuge liang,  group:wadamemo,  artist:wada rco,  artbook,  full color",
        "lastreadtime": 1337038234,
        "title": "Fate GO MEMO 2"
    }, {
        "arcid": "4857fd2e7c00db8b0af0337b94055d8445118630",
        "isnew": "none",
        "extension": "pdf",
        "tags": "artist:shirow masamune",
        "lastreadtime": 1337038234,
        "title": "Ghost in the Shell 1.5 - Human-Error Processor vol01ch01"
    }, {
        "arcid": "e4c422fd10943dc169e3489a38cdbf57101a5f7e",
        "isnew": "none",
        "extension": "epub",
        "tags": "parody: jojo's bizarre adventure",
        "lastreadtime": 0,
        "title": "Rohan Kishibe goes to Gucci"
    }, {
        "arcid": "e69e43e1355267f7d32a4f9b7f2fe108d2401ebf",
        "isnew": "none",
        "extension": "lzma",
        "tags": "character:segata sanshiro",
        "lastreadtime": 1337038236,
        "title": "Saturn Backup Cartridge - Japanese Manual"
    }],
    "draw": 0,
    "recordsFiltered": 5,
    "recordsTotal": 5
}
```
{% endswagger-response %}
{% endswagger %}

{% swagger baseUrl="http://lrr.tvc-16.science" path="/api/search/random" method="get" summary="Get Random Archives out of the Index" %}
{% swagger-description %}
Get randomly selected Archives from the given filter and/or category.
{% endswagger-description %}

{% swagger-parameter name="category" type="string" required="false" in="query" %}
ID of the category you want to restrict this search to.
{% endswagger-parameter %}

{% swagger-parameter name="filter" type="string" required="false" in="query" %}
Search query. This follows the same rules as the queries in `/api/search`.
{% endswagger-parameter %}

{% swagger-parameter name="count" type="int" required="false" in="query" %}
How many archives you want to pull randomly. Defaults to 5.  

If the search doesn't return enough data to match your count, you will get the full search shuffled randomly.
{% endswagger-parameter %}

{% swagger-parameter name="newonly" type="bool" required="false" in="query" %}
Limit search to new archives only.
{% endswagger-parameter %}

{% swagger-parameter name="untaggedonly" type="bool" required="false" in="query" %}
Limit search to untagged archives only.
{% endswagger-parameter %}

{% swagger-parameter name="groupby_tanks" type="bool" required="false" in="query" %}
Enable or disable Tankoubon grouping. Defaults to true.  
When enabled, Tankoubons will show in search results, replacing all the archive IDs they contain. 
{% endswagger-parameter %}

{% swagger-response status="200" description="" %}
```javascript
{
    "recordsTotal": 4, 
    "data": [
        {
        "arcid": "2810d5e0a8d027ecefebca6237031a0fa7b91eb3",
        "isnew": "none",
        "extension": "rar",
        "tags": "parody:fate grand order,  character:abigail williams,  character:artoria pendragon alter,  character:asterios,  character:ereshkigal,  character:gilgamesh,  character:hans christian andersen,  character:hassan of serenity,  character:hector,  character:helena blavatsky,  character:irisviel von einzbern,  character:jeanne alter,  character:jeanne darc,  character:kiara sessyoin,  character:kiyohime,  character:lancer,  character:martha,  character:minamoto no raikou,  character:mochizuki chiyome,  character:mordred pendragon,  character:nitocris,  character:oda nobunaga,  character:osakabehime,  character:penthesilea,  character:queen of sheba,  character:rin tosaka,  character:saber,  character:sakata kintoki,  character:scheherazade,  character:sherlock holmes,  character:suzuka gozen,  character:tamamo no mae,  character:ushiwakamaru,  character:waver velvet,  character:xuanzang,  character:zhuge liang,  group:wadamemo,  artist:wada rco,  artbook,  full color",
        "lastreadtime": 1337038234,
        "title": "Fate GO MEMO 2"
        }, {
            "arcid": "4857fd2e7c00db8b0af0337b94055d8445118630",
            "isnew": "none",
            "extension": "pdf",
            "tags": "artist:shirow masamune",
            "lastreadtime": 1337038234,
            "title": "Ghost in the Shell 1.5 - Human-Error Processor vol01ch01"
        }, {
            "arcid": "e4c422fd10943dc169e3489a38cdbf57101a5f7e",
            "isnew": "none",
            "extension": "epub",
            "tags": "parody: jojo's bizarre adventure",
            "lastreadtime": 0,
            "title": "Rohan Kishibe goes to Gucci"
        }, {
            "arcid": "e69e43e1355267f7d32a4f9b7f2fe108d2401ebf",
            "isnew": "none",
            "extension": "lzma",
            "tags": "character:segata sanshiro",
            "lastreadtime": 1337033234,
            "title": "Saturn Backup Cartridge - Japanese Manual"
        }
    ]
}
```
{% endswagger-response %}
{% endswagger %}

{% swagger baseUrl="http://lrr.tvc-16.science" path="/api/search/cache" method="delete" summary="🔑 Discard Search Cache" %}
{% swagger-description %}
Discard the cache containing previous user searches.
{% endswagger-description %}

{% swagger-response status="200" description="" %}
```
{
  "operation": "clear_cache",
  "success": 1
}
```
{% endswagger-response %}
{% endswagger %}
