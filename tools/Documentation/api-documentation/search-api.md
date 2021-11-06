---
description: Perform searches.
---

# Search API

{% api-method method="get" host="http://lrr.tvc-16.science" path="/api/search" %}
{% api-method-summary %}
Search the Archive Index
{% endapi-method-summary %}

{% api-method-description %}
Search for Archives. You can use the IDs of this JSON with the other endpoints.
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}
{% api-method-query-parameters %}
{% api-method-parameter name="category" type="string" required=false %}
ID of the category you want to restrict this search to.
{% endapi-method-parameter %}

{% api-method-parameter name="filter" type="string" required=false %}
Search query. You can use the following special characters in it:  
**Quotation Marks \("..."\)**  
Exact string search. Allows a search term to include spaces. Everything placed inside a pair of quotation marks is treated as a singular term. Wildcard characters are still interpreted as wildcards.**Question Mark \(?\), Underscore \(\_\)**  
Wildcard. Can match any single character.**Asterisk \(\*\), Percentage Sign \(%\)**  
Wildcard. Can match any sequence of characters \(including none\).**Subtraction Sign \(-\)**  
Exclusion. When placed before a term, prevents search results from including that term.**Dollar Sign \($\)**  
Add at the end of a tag to perform an exact tag search rather than displaying all elements that start with the term. Only matches tags regardless of search parameters and can be used as an exclusion to ignore misc tags in the search query.
{% endapi-method-parameter %}

{% api-method-parameter name="start" type="string" required=false %}
From which archive in the total result count this enumeration should start. The total number of archives displayed depends on the server-side _page size_ preference.  
From 0.8.2 onwards, you can use "-1" here to get the full, unpaged data.  
{% endapi-method-parameter %}

{% api-method-parameter name="sortby" type="string" required=false %}
Namespace by which you want to sort the results, or _title_ if you want to sort by title. \(Default value is title.\)
{% endapi-method-parameter %}

{% api-method-parameter name="order" type="string" required=false %}
Order of the sort, either `asc` or `desc`.
{% endapi-method-parameter %}
{% endapi-method-query-parameters %}
{% endapi-method-request %}

{% api-method-response %}
{% api-method-response-example httpCode=200 %}
{% api-method-response-example-description %}
Search is performed.
{% endapi-method-response-example-description %}

```javascript
{
    "data": [{
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
        "arcid": "4857fd2e7c00db8b0af0337b94055d8445118630",
        "isnew": "none",
        "tags": "artist:shirow masamune",
        "title": "Ghost in the Shell 1.5 - Human-Error Processor vol01ch01"
    }, {
        "arcid": "e4c422fd10943dc169e3489a38cdbf57101a5f7e",
        "isnew": "none",
        "tags": "parody: jojo's bizarre adventure",
        "title": "Rohan Kishibe goes to Gucci"
    }, {
        "arcid": "e69e43e1355267f7d32a4f9b7f2fe108d2401ebf",
        "isnew": "none",
        "tags": "character:segata sanshiro",
        "title": "Saturn Backup Cartridge - Japanese Manual"
    }],
    "draw": 0,
    "recordsFiltered": 5,
    "recordsTotal": 5
}
```
{% endapi-method-response-example %}
{% endapi-method-response %}
{% endapi-method-spec %}
{% endapi-method %}

{% api-method method="get" host="http://lrr.tvc-16.science" path="/api/search/random" %}
{% api-method-summary %}
Get Random Archives out of the Index.
{% endapi-method-summary %}

{% api-method-description %}
Get randomly selected Archives from the given filter and/or category. 
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}
{% api-method-query-parameters %}
{% api-method-parameter name="category" type="string" required=false %}
ID of the category you want to restrict this search to.
{% endapi-method-parameter %}

{% api-method-parameter name="filter" type="string" required=false %}
Search query. This follows the same rules as the queries in `/api/search`.
{% endapi-method-parameter %}

{% api-method-parameter name="count" type="int" required=false %}
How many archives you want to pull randomly. Defaults to 5.  
If the search doesn't return enough data to match your count, you will get the full search shuffled randomly.
{% endapi-method-parameter %}
{% endapi-method-query-parameters %}
{% endapi-method-request %}

{% api-method-response %}
{% api-method-response-example httpCode=200 %}
{% api-method-response-example-description %}
You get random archives. This endpoint doesn't yield as much data as the full search.
{% endapi-method-response-example-description %}

```javascript
[
    {
        "id": "28697b96f0ac5858be2614ed10ca47742c9522fd",
        "tags": "parody:fate grand order,  group:wadamemo,  artist:wada rco,  artbook,  full color",
        "title": "Fate GO MEMO"
    }, {
        "id": "2810d5e0a8d027ecefebca6237031a0fa7b91eb3",
        "tags": "parody:fate grand order,  character:abigail williams,  character:artoria pendragon alter,  character:asterios,  character:ereshkigal,  character:gilgamesh,  character:hans christian andersen,  character:hassan of serenity,  character:hector,  character:helena blavatsky,  character:irisviel von einzbern,  character:jeanne alter,  character:jeanne darc,  character:kiara sessyoin,  character:kiyohime,  character:lancer,  character:martha,  character:minamoto no raikou,  character:mochizuki chiyome,  character:mordred pendragon,  character:nitocris,  character:oda nobunaga,  character:osakabehime,  character:penthesilea,  character:queen of sheba,  character:rin tosaka,  character:saber,  character:sakata kintoki,  character:scheherazade,  character:sherlock holmes,  character:suzuka gozen,  character:tamamo no mae,  character:ushiwakamaru,  character:waver velvet,  character:xuanzang,  character:zhuge liang,  group:wadamemo,  artist:wada rco,  artbook,  full color",
        "title": "Fate GO MEMO 2"
    }, {
        "id": "4857fd2e7c00db8b0af0337b94055d8445118630",
        "tags": "artist:shirow masamune",
        "title": "Ghost in the Shell 1.5 - Human-Error Processor vol01ch01"
    }, {
        "id": "e4c422fd10943dc169e3489a38cdbf57101a5f7e",
        "tags": "parody: jojo's bizarre adventure",
        "title": "Rohan Kishibe goes to Gucci"
    }, {
        "id": "e69e43e1355267f7d32a4f9b7f2fe108d2401ebf",
        "tags": "character:segata sanshiro",
        "title": "Saturn Backup Cartridge - Japanese Manual"
    }
]
```
{% endapi-method-response-example %}
{% endapi-method-response %}
{% endapi-method-spec %}
{% endapi-method %}


{% api-method method="delete" host="http://lrr.tvc-16.science" path="/api/search/cache" %}
{% api-method-summary %}
🔑 Discard Search Cache
{% endapi-method-summary %}

{% api-method-description %}
Discard the cache containing previous user searches.
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}
{% api-method-query-parameters %}
{% endapi-method-query-parameters %}
{% endapi-method-request %}

{% api-method-response %}
{% api-method-response-example httpCode=200 %}
{% api-method-response-example-description %}
Cache is wiped.
{% endapi-method-response-example-description %}

```
{
  "operation": "clear_cache",
  "success": 1
}
```
{% endapi-method-response-example %}
{% endapi-method-response %}
{% endapi-method-spec %}
{% endapi-method %}

