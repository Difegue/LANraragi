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
ID of an archive. Passing this will show only one `<entry\>` for the given ID in the result, instead of all the archives.
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
<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom"
      xmlns:dcterms="http://purl.org/dc/terms/"
      xmlns:opds="http://opds-spec.org/2010/catalog">

  <id>urn:lrr:0</id>

  <link rel="self"    
        href="/api/opds"
        type="application/atom+xml;profile=opds-catalog;kind=acquisition"/>

  <link rel="start"    
        href="/api/opds"
        type="application/atom+xml;profile=opds-catalog;kind=acquisition"/>

  <title>LANraragi Demo</title>
  <updated>2010-01-10T10:03:10Z</updated>
  <subtitle>LANraragi Demo, running in Docker @ TVC-16</subtitle>
  <icon>/favicon.ico</icon>
  <author>
    <name>0.6.6</name>
    <uri>http://github.org/Difegue/LANraragi</uri>
  </author>

  
  <entry>
      <title>Ghost in the Shell 1.5 - Human-Error Processor vol01ch01</title>
      <id>urn:lrr:4857fd2e7c00db8b0af0337b94055d8445118630</id>
      <updated>2010-01-10T10:01:11Z</updated>
      <published>2010-01-10T10:01:11Z</published>
      <author>
          <name>shirow masamune</name>
      </author>
      <rights></rights>
      <dcterms:language></dcterms:language>
      <dcterms:publisher></dcterms:publisher>
      <dcterms:issued></dcterms:issued>
      
      <category term="Archive"/>
      
      <summary>artist:shirow masamune</summary>
      
      <link rel="alternate"
          href="/api/opds?id=4857fd2e7c00db8b0af0337b94055d8445118630"
          type="application/atom+xml;type=entry;profile=opds-catalog" />
  
      <link rel="http://opds-spec.org/image" href="/api/thumbnail?id=4857fd2e7c00db8b0af0337b94055d8445118630" type="image/jpeg"/>
      <link rel="http://opds-spec.org/image/thumbnail" href="/api/thumbnail?id=4857fd2e7c00db8b0af0337b94055d8445118630" type="image/jpeg"/>
      <link rel="http://opds-spec.org/acquisition" href="/api/servefile?id=4857fd2e7c00db8b0af0337b94055d8445118630" type="application/x-cbz"/>
      <link rel="http://opds-spec.org/acquisition" href="/api/servefile?id=4857fd2e7c00db8b0af0337b94055d8445118630" title="Read" type="application/cbz"/>
      <link type="text/html" rel="alternate" title="Open in LANraragi" href="/reader?id=4857fd2e7c00db8b0af0337b94055d8445118630"/>
  </entry>
  
  <entry>
      <title>Fate GO MEMO 2</title>
      <id>urn:lrr:2810d5e0a8d027ecefebca6237031a0fa7b91eb3</id>
      <updated>2010-01-10T10:01:11Z</updated>
      <published>2010-01-10T10:01:11Z</published>
      <author>
          <name>wada rco</name>
      </author>
      <rights></rights>
      <dcterms:language></dcterms:language>
      <dcterms:publisher>wadamemo</dcterms:publisher>
      <dcterms:issued></dcterms:issued>
      
      <category term="Archive"/>
      
      <summary>parody:fate grand order,  character:abigail williams,  character:artoria pendragon alter,  character:asterios,  character:ereshkigal,  character:gilgamesh,  character:hans christian andersen,  character:hassan of serenity,  character:hector,  character:helena blavatsky,  character:irisviel von einzbern,  character:jeanne alter,  character:jeanne darc,  character:kiara sessyoin,  character:kiyohime,  character:lancer,  character:martha,  character:minamoto no raikou,  character:mochizuki chiyome,  character:mordred pendragon,  character:nitocris,  character:oda nobunaga,  character:osakabehime,  character:penthesilea,  character:queen of sheba,  character:rin tosaka,  character:saber,  character:sakata kintoki,  character:scheherazade,  character:sherlock holmes,  character:suzuka gozen,  character:tamamo no mae,  character:ushiwakamaru,  character:waver velvet,  character:xuanzang,  character:zhuge liang,  group:wadamemo,  artist:wada rco,  artbook,  full color</summary>
      
      <link rel="alternate"
          href="/api/opds?id=2810d5e0a8d027ecefebca6237031a0fa7b91eb3"
          type="application/atom+xml;type=entry;profile=opds-catalog" />
  
      <link rel="http://opds-spec.org/image" href="/api/thumbnail?id=2810d5e0a8d027ecefebca6237031a0fa7b91eb3" type="image/jpeg"/>
      <link rel="http://opds-spec.org/image/thumbnail" href="/api/thumbnail?id=2810d5e0a8d027ecefebca6237031a0fa7b91eb3" type="image/jpeg"/>
      <link rel="http://opds-spec.org/acquisition" href="/api/servefile?id=2810d5e0a8d027ecefebca6237031a0fa7b91eb3" type="application/x-cbz"/>
      <link rel="http://opds-spec.org/acquisition" href="/api/servefile?id=2810d5e0a8d027ecefebca6237031a0fa7b91eb3" title="Read" type="application/cbz"/>
      <link type="text/html" rel="alternate" title="Open in LANraragi" href="/reader?id=2810d5e0a8d027ecefebca6237031a0fa7b91eb3"/>
  </entry>
  
  <entry>
      <title>Saturn Backup Cartridge - Japanese Manual</title>
      <id>urn:lrr:e69e43e1355267f7d32a4f9b7f2fe108d2401ebf</id>
      <updated>2010-01-10T10:01:11Z</updated>
      <published>2010-01-10T10:01:11Z</published>
      <author>
          <name></name>
      </author>
      <rights></rights>
      <dcterms:language></dcterms:language>
      <dcterms:publisher></dcterms:publisher>
      <dcterms:issued></dcterms:issued>
      
      <category term="Archive"/>
      
      <summary>character:segata sanshiro</summary>
      
      <link rel="alternate"
          href="/api/opds?id=e69e43e1355267f7d32a4f9b7f2fe108d2401ebf"
          type="application/atom+xml;type=entry;profile=opds-catalog" />
  
      <link rel="http://opds-spec.org/image" href="/api/thumbnail?id=e69e43e1355267f7d32a4f9b7f2fe108d2401ebf" type="image/jpeg"/>
      <link rel="http://opds-spec.org/image/thumbnail" href="/api/thumbnail?id=e69e43e1355267f7d32a4f9b7f2fe108d2401ebf" type="image/jpeg"/>
      <link rel="http://opds-spec.org/acquisition" href="/api/servefile?id=e69e43e1355267f7d32a4f9b7f2fe108d2401ebf" type="application/x-cbr"/>
      <link rel="http://opds-spec.org/acquisition" href="/api/servefile?id=e69e43e1355267f7d32a4f9b7f2fe108d2401ebf" title="Read" type="application/cbr"/>
      <link type="text/html" rel="alternate" title="Open in LANraragi" href="/reader?id=e69e43e1355267f7d32a4f9b7f2fe108d2401ebf"/>
  </entry>
  
  <entry>
      <title>Rohan Kishibe goes to Gucci</title>
      <id>urn:lrr:e4c422fd10943dc169e3489a38cdbf57101a5f7e</id>
      <updated>2010-01-10T10:01:11Z</updated>
      <published>2010-01-10T10:01:11Z</published>
      <author>
          <name></name>
      </author>
      <rights></rights>
      <dcterms:language></dcterms:language>
      <dcterms:publisher></dcterms:publisher>
      <dcterms:issued></dcterms:issued>
      
      <category term="Archive"/>
      
      <summary>parody: jojo's bizarre adventure</summary>
      
      <link rel="alternate"
          href="/api/opds?id=e4c422fd10943dc169e3489a38cdbf57101a5f7e"
          type="application/atom+xml;type=entry;profile=opds-catalog" />
  
      <link rel="http://opds-spec.org/image" href="/api/thumbnail?id=e4c422fd10943dc169e3489a38cdbf57101a5f7e" type="image/jpeg"/>
      <link rel="http://opds-spec.org/image/thumbnail" href="/api/thumbnail?id=e4c422fd10943dc169e3489a38cdbf57101a5f7e" type="image/jpeg"/>
      <link rel="http://opds-spec.org/acquisition" href="/api/servefile?id=e4c422fd10943dc169e3489a38cdbf57101a5f7e" type="application/x-cbz"/>
      <link rel="http://opds-spec.org/acquisition" href="/api/servefile?id=e4c422fd10943dc169e3489a38cdbf57101a5f7e" title="Read" type="application/cbz"/>
      <link type="text/html" rel="alternate" title="Open in LANraragi" href="/reader?id=e4c422fd10943dc169e3489a38cdbf57101a5f7e"/>
  </entry>
  
  <entry>
      <title>Fate GO MEMO</title>
      <id>urn:lrr:28697b96f0ac5858be2614ed10ca47742c9522fd</id>
      <updated>2010-01-10T10:01:11Z</updated>
      <published>2010-01-10T10:01:11Z</published>
      <author>
          <name>wada rco</name>
      </author>
      <rights></rights>
      <dcterms:language></dcterms:language>
      <dcterms:publisher>wadamemo</dcterms:publisher>
      <dcterms:issued></dcterms:issued>
      
      <category term="Archive"/>
      
      <summary>parody:fate grand order,  group:wadamemo,  artist:wada rco,  artbook,  full color</summary>
      
      <link rel="alternate"
          href="/api/opds?id=28697b96f0ac5858be2614ed10ca47742c9522fd"
          type="application/atom+xml;type=entry;profile=opds-catalog" />
  
      <link rel="http://opds-spec.org/image" href="/api/thumbnail?id=28697b96f0ac5858be2614ed10ca47742c9522fd" type="image/jpeg"/>
      <link rel="http://opds-spec.org/image/thumbnail" href="/api/thumbnail?id=28697b96f0ac5858be2614ed10ca47742c9522fd" type="image/jpeg"/>
      <link rel="http://opds-spec.org/acquisition" href="/api/servefile?id=28697b96f0ac5858be2614ed10ca47742c9522fd" type="application/x-cbz"/>
      <link rel="http://opds-spec.org/acquisition" href="/api/servefile?id=28697b96f0ac5858be2614ed10ca47742c9522fd" title="Read" type="application/cbz"/>
      <link type="text/html" rel="alternate" title="Open in LANraragi" href="/reader?id=28697b96f0ac5858be2614ed10ca47742c9522fd"/>
  </entry>
  

</feed>
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

{% api-method-parameter name="untaggedonly" type="boolean" required=false %}
Set to `true` to only show untagged archives.
{% endapi-method-parameter %}

{% endapi-method-path-parameters %}
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
    "pages": [".\/api\/page?id=28697b96f0ac5858be2614ed10ca47742c9522fd&path=00.jpg",
        ".\/api\/page?id=28697b96f0ac5858be2614ed10ca47742c9522fd&path=01.jpg",
        ".\/api\/page?id=28697b96f0ac5858be2614ed10ca47742c9522fd&path=03.jpg",
        ".\/api\/page?id=28697b96f0ac5858be2614ed10ca47742c9522fd&path=04.jpg",
        ".\/api\/page?id=28697b96f0ac5858be2614ed10ca47742c9522fd&path=05.jpg",
        ".\/api\/page?id=28697b96f0ac5858be2614ed10ca47742c9522fd&path=06.jpg",
        ".\/api\/page?id=28697b96f0ac5858be2614ed10ca47742c9522fd&path=07.jpg",
        ".\/api\/page?id=28697b96f0ac5858be2614ed10ca47742c9522fd&path=08.jpg",
        ".\/api\/page?id=28697b96f0ac5858be2614ed10ca47742c9522fd&path=09.jpg",
        ".\/api\/page?id=28697b96f0ac5858be2614ed10ca47742c9522fd&path=20.jpg",
        ".\/api\/page?id=28697b96f0ac5858be2614ed10ca47742c9522fd&path=21.jpg",
        ".\/api\/page?id=28697b96f0ac5858be2614ed10ca47742c9522fd&path=22.jpg",
        ".\/api\/page?id=28697b96f0ac5858be2614ed10ca47742c9522fd&path=23.jpg",
        ".\/api\/page?id=28697b96f0ac5858be2614ed10ca47742c9522fd&path=24.jpg",
        ".\/api\/page?id=28697b96f0ac5858be2614ed10ca47742c9522fd&path=25.jpg",
        ".\/api\/page?id=28697b96f0ac5858be2614ed10ca47742c9522fd&path=26.jpg",
        ".\/api\/page?id=28697b96f0ac5858be2614ed10ca47742c9522fd&path=27.jpg",
        ".\/api\/page?id=28697b96f0ac5858be2614ed10ca47742c9522fd&path=28.jpg",
        ".\/api\/page?id=28697b96f0ac5858be2614ed10ca47742c9522fd&path=29.jpg",
        ".\/api\/page?id=28697b96f0ac5858be2614ed10ca47742c9522fd&path=30.jpg",
        ".\/api\/page?id=28697b96f0ac5858be2614ed10ca47742c9522fd&path=31.jpg",
        ".\/api\/page?id=28697b96f0ac5858be2614ed10ca47742c9522fd&path=32.jpg",
        ".\/api\/page?id=28697b96f0ac5858be2614ed10ca47742c9522fd&path=33.jpg",
        ".\/api\/page?id=28697b96f0ac5858be2614ed10ca47742c9522fd&path=34.jpg",
        ".\/api\/page?id=28697b96f0ac5858be2614ed10ca47742c9522fd&path=35.jpg",
        ".\/api\/page?id=28697b96f0ac5858be2614ed10ca47742c9522fd&path=36.jpg",
        ".\/api\/page?id=28697b96f0ac5858be2614ed10ca47742c9522fd&path=37.jpg",
        ".\/api\/page?id=28697b96f0ac5858be2614ed10ca47742c9522fd&path=38.jpg",
        ".\/api\/page?id=28697b96f0ac5858be2614ed10ca47742c9522fd&path=39.jpg",
        ".\/api\/page?id=28697b96f0ac5858be2614ed10ca47742c9522fd&path=40.jpg"
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
Scans the entire database and returns a backup in JSON form. This backup can be reimported manually through the [Backup and Restore](../advanced-usage/backup-and-restore.md) feature.  
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

{% api-method method="get" host="http://lrr.tvc-16.science" path="/api/use\_plugin" %}
{% api-method-summary %}
Use a Plugin.
{% endapi-method-summary %}

{% api-method-description %}
Uses a Plugin and returns the result. If using a metadata plugin, the matching archive will **not** be modified in the database.  
See more info on Plugins [here](../plugin-docs/index.md).  
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}
{% api-method-path-parameters %}
{% api-method-parameter name="key" type="string" required=true %}
API Key, mandatory for this method.
{% endapi-method-parameter %}
{% api-method-parameter name="plugin" type="string" required=true %}
Namespace of the plugin to use.  
{% endapi-method-parameter %}
{% api-method-parameter name="id" type="string" required=false %}
ID of the archive to use the Plugin on. This is only mandatory for metadata plugins.
{% endapi-method-parameter %}
{% api-method-parameter name="arg" type="string" required=false %}
Optional One-Shot argument to use when executing this Plugin.
{% endapi-method-parameter %}
{% endapi-method-path-parameters %}
{% endapi-method-request %}

{% api-method-response %}
{% api-method-response-example httpCode=200 %}
{% api-method-response-example-description %}
Executes the Plugin and returns the result.
{% endapi-method-response-example-description %}

```javascript
{
    "data":{
        "new_tags":" zawarudo"
        },
    "operation":"use_plugin",
    "success":1,
    "type":"metadata"
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

