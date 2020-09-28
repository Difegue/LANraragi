---
description: Other APIs that don't fit a dedicated theme.
---


# Miscellaneous other API

{% api-method method="get" host="http://lrr.tvc-16.science" path="/api/info" %}
{% api-method-summary %}
Get information about the server
{% endapi-method-summary %}

{% api-method-description %}
Returns some basic information about the LRR instance this server is running.
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}
{% endapi-method-request %}
{% api-method-response %}
{% api-method-response-example httpCode=200 %}
{% api-method-response-example-description %}
You get server info.
{% endapi-method-response-example-description %}

```javascript
{
    "name":"LANraragi",
    "motd":"Welcome to this Library running LANraragi !",
    "version":"0.7.0",
    "version_name":"Cat People (Putting Out Fire)",
    "has_password": "1",
    "debug_mode":"1",
    "nofun_mode":"0",
    "archives_per_page":"100",
    "server_resizes_images":"0"
}
```  

{% endapi-method-response-example %}
{% endapi-method-response %}
{% endapi-method-spec %}
{% endapi-method %}

{% api-method method="get" host="http://lrr.tvc-16.science" path="/api/opds" %}
{% api-method-summary %}
Get the OPDS Catalog
{% endapi-method-summary %}

{% api-method-description %}
Get the Archive Index as an OPDS 1.2 Catalog.
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}
{% api-method-query-parameters %}
{% api-method-parameter name="id" type="string" required=false %}
ID of an archive. Passing this will show only one `<entry\>` for the given ID in the result, instead of all the archives.
{% endapi-method-parameter %}
{% endapi-method-query-parameters %}
{% endapi-method-request %}

{% api-method-response %}
{% api-method-response-example httpCode=200 %}
{% api-method-response-example-description %}
The OPDS Catalog is generated.   
This API is mostly meant to be used as-is by external software implementing the spec.
{% endapi-method-response-example-description %}

```markup
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

      <link rel="http://opds-spec.org/image" href="/api/archives/4857fd2e7c00db8b0af0337b94055d8445118630/thumbnail" type="image/jpeg"/>
      <link rel="http://opds-spec.org/image/thumbnail" href="/api/archives/4857fd2e7c00db8b0af0337b94055d8445118630/thumbnail" type="image/jpeg"/>
      <link rel="http://opds-spec.org/acquisition" href="/api/archives/4857fd2e7c00db8b0af0337b94055d8445118630/download" type="application/x-cbz"/>
      <link rel="http://opds-spec.org/acquisition" href="/api/archives/4857fd2e7c00db8b0af0337b94055d8445118630/download" title="Read" type="application/cbz"/>
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

      <link rel="http://opds-spec.org/image" href="/api/archives/2810d5e0a8d027ecefebca6237031a0fa7b91eb3/thumbnail" type="image/jpeg"/>
      <link rel="http://opds-spec.org/image/thumbnail" href="/api/archives/2810d5e0a8d027ecefebca6237031a0fa7b91eb3/thumbnail" type="image/jpeg"/>
      <link rel="http://opds-spec.org/acquisition" href="/api/archives/2810d5e0a8d027ecefebca6237031a0fa7b91eb3/download" type="application/x-cbz"/>
      <link rel="http://opds-spec.org/acquisition" href="/api/archives/2810d5e0a8d027ecefebca6237031a0fa7b91eb3/download" title="Read" type="application/cbz"/>
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

      <link rel="http://opds-spec.org/image" href="/api/archives/e69e43e1355267f7d32a4f9b7f2fe108d2401ebf/thumbnail" type="image/jpeg"/>
      <link rel="http://opds-spec.org/image/thumbnail" href="/api/archives/e69e43e1355267f7d32a4f9b7f2fe108d2401ebf/thumbnail" type="image/jpeg"/>
      <link rel="http://opds-spec.org/acquisition" href="/api/archives/e69e43e1355267f7d32a4f9b7f2fe108d2401ebf/download" type="application/x-cbr"/>
      <link rel="http://opds-spec.org/acquisition" href="/api/archives/e69e43e1355267f7d32a4f9b7f2fe108d2401ebf/download" title="Read" type="application/cbr"/>
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

      <link rel="http://opds-spec.org/image" href="/api/archives/e4c422fd10943dc169e3489a38cdbf57101a5f7e/thumbnail" type="image/jpeg"/>
      <link rel="http://opds-spec.org/image/thumbnail" href="/api/archives/e4c422fd10943dc169e3489a38cdbf57101a5f7e/thumbnail" type="image/jpeg"/>
      <link rel="http://opds-spec.org/acquisition" href="/api/archives/e4c422fd10943dc169e3489a38cdbf57101a5f7e/download" type="application/x-cbz"/>
      <link rel="http://opds-spec.org/acquisition" href="/api/archives/e4c422fd10943dc169e3489a38cdbf57101a5f7e/download" title="Read" type="application/cbz"/>
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

      <link rel="http://opds-spec.org/image" href="/api/archives/28697b96f0ac5858be2614ed10ca47742c9522fd/thumbnail" type="image/jpeg"/>
      <link rel="http://opds-spec.org/image/thumbnail" href="/api/archives/28697b96f0ac5858be2614ed10ca47742c9522fd/thumbnail" type="image/jpeg"/>
      <link rel="http://opds-spec.org/acquisition" href="/api/archives/28697b96f0ac5858be2614ed10ca47742c9522fd/download" type="application/x-cbz"/>
      <link rel="http://opds-spec.org/acquisition" href="/api/archives/28697b96f0ac5858be2614ed10ca47742c9522fd/download" title="Read" type="application/cbz"/>
      <link type="text/html" rel="alternate" title="Open in LANraragi" href="/reader?id=28697b96f0ac5858be2614ed10ca47742c9522fd"/>
  </entry>


</feed>
```  

{% endapi-method-response-example %}
{% endapi-method-response %}
{% endapi-method-spec %}
{% endapi-method %}

{% api-method method="get" host="http://lrr.tvc-16.science" path="/api/plugins/:type" %}
{% api-method-summary %}
🔑Get available plugins
{% endapi-method-summary %}

{% api-method-description %}
Get a list of the available plugins on the server, filtered by type.
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}
{% api-method-path-parameters %}
{% api-method-parameter name="type" type="string" required=true %}
Type of plugins you want to list.  
You can either use `login`, `metadata`, `script`, or `all` to get all previous types at once.
{% endapi-method-parameter %}
{% endapi-method-path-parameters %}
{% endapi-method-request %}
{% api-method-response %}
{% api-method-response-example httpCode=200 %}
{% api-method-response-example-description %}
You get plugin info.  
Said information is a 1:1 match to the [plugin metadata](../plugin-docs/index#plugin-metadata).
{% endapi-method-response-example-description %}

```javascript
[
  {
    "author": "Difegue",
    "description": "Searches chaika.moe for tags matching your archive.",
    "icon": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAACXBIWXMAAAsTAAALEwEAmpwYAAAA\nB3RJTUUH4wYCFQocjU4r+QAAAB1pVFh0Q29tbWVudAAAAAAAQ3JlYXRlZCB3aXRoIEdJTVBkLmUH\nAAAEZElEQVQ4y42T3WtTdxzGn/M7J+fk5SRpTk7TxMZkXU84tTbVNrUT3YxO7HA4pdtQZDe7cgx2\ns8vBRvEPsOwFYTDYGJUpbDI2wV04cGXCGFLonIu1L2ptmtrmxeb1JDkvv121ZKVze66f74eH7/f5\nMmjRwMCAwrt4/9KDpflMJpPHvyiR2DPcJklJ3TRDDa0xk36cvrm8vDwHAAwAqKrqjjwXecPG205w\nHBuqa9rk77/d/qJYLD7cCht5deQIIczbgiAEKLVAKXWUiqVV06Tf35q8dYVJJBJem2A7Kwi2nQzD\nZig1CG93+PO5/KN6tf5NKpVqbsBUVVVFUUxwHJc1TXNBoxojS7IbhrnLMMx9pVJlBqFQKBKPxwcB\nkJYgjKIo3QCE1nSKoghbfJuKRqN2RVXexMaQzWaLezyeEUEQDjscjk78PxFFUYRkMsltJgGA3t7e\nyMLCwie6rr8iCILVbDbvMgwzYRjGxe0o4XC4s1AoHPP5fMP5/NNOyzLKAO6Ew+HrDADBbre/Ryk9\nnzx81FXJNlEpVpF+OqtpWu2MpmnXWmH9/f2umZmZi4cOHXnLbILLzOchhz1YerJAs9m1GwRAg2GY\nh7GYah488BJYzYW+2BD61AFBlmX/1nSNRqN9//792ujoaIPVRMjOKHoie3DytVGmp2fXCAEAjuMm\nu7u7Umosho6gjL/u/QHeEgvJZHJ2K/D+/fuL4+PjXyvPd5ldkShy1UXcmb4DnjgQj/fd5gDA6/XS\nYCAwTwh9oT3QzrS1+VDVi+vd3Tsy26yQVoFF3dAXJVmK96p9EJ0iLNOwKKU3CQCk0+lSOpP5WLDz\nF9Q9kZqyO0SloOs6gMfbHSU5NLRiUOuax2/HyZPHEOsLw2SbP83eu/fLxrkNp9P554XxCzVa16MC\n7+BPnTk9cfmH74KJE8nmga7Xy5JkZ8VKifGIHpoBb1VX8hNTd3/t/7lQ3OeXfFPvf/jBRw8ezD/a\n7M/aWq91cGgnJaZ2VcgSdnV1XRNNd3vAoBVVYusmnEQS65hfgSG6c+zy3Kre7nF/KrukcMW0Zg8O\nD08DoJutDxxOEb5IPUymwrq8ft1gLKfkFojkkRxemERCAQUACPFWRazYLJcrFGwQhyufbQQ7rFpy\nLMkCwGZC34qPIuwp+XPOjBFwazQ/txrdFS2GGS/Xuj+pUKLGk1Kjvlded3s72lyGW+PLbGVcmrAA\ngN0wTk1NWYODg9XOKltGtpazi5GigzroUnHN5nUHG1ylRsG7rDXHmnEpu4CeEtEKkqNc6QqlLc/M\n8uT5lLH5eq0aGxsju1O7GQB498a5s/0x9dRALPaQEDZnYwnhWJtMCCNrjeb0UP34Z6e/PW22zjPP\n+vwXBwfPvbw38XnXjk7GsiwKAIQQhjAMMrlsam45d+zLH6/8o6vkWcBcrXbVKQhf6bpucCwLjmUB\nSmmhXC419eblrbD/TAgAkUjE987xE0c7ZDmk66ajUCnq+cL63fErl25s5/8baQPaWLhx6goAAAAA\nSUVORK5CYII=",
    "name": "Chaika.moe",
    "namespace": "trabant",
    "oneshot_arg": "Chaika Gallery or Archive URL (Will attach matching tags to your archive)",
    "parameters": [
      {
        "desc": "Save archive title",
        "type": "bool"
      }
    ],
    "type": "metadata",
    "version": "2.1"
  },
  {
    "author": "Difegue",
    "description": "Apply custom tag modifications.",
    "name": "Tag Copier",
    "namespace": "copytags",
    "parameters": [
      {
        "desc": "Tags to copy, separated by commas.",
        "type": "string"
      }
    ],
    "type": "metadata",
    "version": "2.1"
  },
  {
    "author": "Utazukin",
    "description": "Adds the unix time stamp of the date the archive was added as a tag under the \"date_added\" namespace.",
    "name": "Date Added",
    "namespace": "DateAddedPlugin",
    "oneshot_arg": "Use file modified time (yes/true), or use current time (no/false). <br/>Leaving blank uses the global setting (default: current time)",
    "parameters": [
      {
        "desc": "Use file modified time instead of current time.",
        "type": "bool"
      }
    ],
    "type": "metadata",
    "version": "0.3"
  }
  {
    "author": "Difegue",
    "description": "Collects metadata embedded into your archives by the eze userscript. (info.json files)",
    "name": "eze",
    "namespace": "ezeplugin",
    "parameters": [
      {
        "desc": "Save archive title",
        "type": "bool"
      }
    ],
    "type": "metadata",
    "version": "2.2"
  },
  {
    "author": "Pao",
    "description": "Collects metadata embedded into your archives by HDoujin Downloader's json or txt files.",
    "name": "Hdoujin",
    "namespace": "Hdoujinplugin",
    "parameters": [],
    "type": "metadata",
    "version": "0.5"
  },
  {
    "author": "CirnoT",
    "description": "Collects metadata embedded into your archives by the Koromo Copy downloader. (Info.json files)",
    "name": "koromo",
    "namespace": "koromoplugin",
    "parameters": [],
    "type": "metadata",
    "version": "1.1"
  },
  {
    "author": "Difegue",
    "description": "Searches nHentai for tags matching your archive."
    "name": "nHentai",
    "namespace": "nhplugin",
    "oneshot_arg": "nHentai Gallery URL (Will attach tags matching this exact gallery to your archive)",
    "parameters": [
      {
        "desc": "Save archive title",
        "type": "bool"
      }
    ],
    "type": "metadata",
    "version": "1.6"
  }
]
```

{% endapi-method-response-example %}
{% endapi-method-response %}
{% endapi-method-spec %}
{% endapi-method %}

{% api-method method="post" host="http://lrr.tvc-16.science" path="/api/plugins/use" %}
{% api-method-summary %}
🔑Use a Plugin
{% endapi-method-summary %}

{% api-method-description %}
Uses a Plugin and returns the result.   
If using a metadata plugin, the matching archive will **not** be modified in the database.  
See more info on Plugins in the matching section of the Docs.
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}
{% api-method-query-parameters %}
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
{% endapi-method-query-parameters %}
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
{% endapi-method-response %}
{% endapi-method-spec %}
{% endapi-method %}

{% api-method method="delete" host="http://lrr.tvc-16.science" path="/api/tempfolder" %}
{% api-method-summary %}
🔑Clean the Temporary Folder
{% endapi-method-summary %}

{% api-method-description %}
Cleans the server's temporary folder.
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}
{% endapi-method-request %}

{% api-method-response %}
{% api-method-response-example httpCode=200 %}
{% api-method-response-example-description %}
Temporary folder is deleted.
{% endapi-method-response-example-description %}

```javascript
{
  "error": "",
  "newsize": 0.0,
  "operation": "cleantemp",
  "success": 1
}
```  

{% endapi-method-response-example %}
{% endapi-method-response %}
{% endapi-method-spec %}
{% endapi-method %}

{% api-method method="post" host="http://lrr.tvc-16.science" path="/api/download_url" %}
{% api-method-summary %}
🔑Queue a URL download
{% endapi-method-summary %}

{% api-method-description %}
Add a URL to be downloaded by the server and added to its library.
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}
{% api-method-path-parameters %}
{% api-method-parameter name="url" type="string" required=true %}
URL to download  
{% endapi-method-parameter %}
{% endapi-method-path-parameters %}
{% endapi-method-request %}

{% api-method-response %}
{% api-method-response-example httpCode=200 %}
{% api-method-response-example-description %}
You get the Minion Job ID for the ongoing download. Status for the job can be verified using the `/api/minion/:jobid` endpoint.
{% endapi-method-response-example-description %}

```javascript
{
  "job": 86,
  "operation": "download_url",
  "success": 1,
  "url": "https:\/\/example.com"
}
```  

{% endapi-method-response-example %}
{% endapi-method-response %}
{% endapi-method-spec %}
{% endapi-method %}

{% api-method method="get" host="http://lrr.tvc-16.science" path="/api/minion/:jobid" %}
{% api-method-summary %}
🔑Get the status of a Minion Job
{% endapi-method-summary %}

{% api-method-description %}
Get the status of a Minion Job. Minions jobs are ran for various occasions like thumbnails, cache warmup and handling incoming files.  
Usually stuff you don't need to care about as a client, but the API is there for internal usage mostly.
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}
{% api-method-path-parameters %}
{% api-method-parameter name="id" type="string" required=true %}
ID of the Job.  
{% endapi-method-parameter %}
{% endapi-method-path-parameters %}
{% endapi-method-request %}

{% api-method-response %}
{% api-method-response-example httpCode=200 %}
{% api-method-response-example-description %}
You get the job status. This is essentially "raw" output from Minion and looks a bit different from usual API calls.
{% endapi-method-response-example-description %}

```javascript
{
  "args": ["\/tmp\/QF3UCnKdMr\/myfile.zip"],
  "attempts": 1,
  "children": [],
  "created": "1601145004",
  "delayed": "1601145004",
  "expires": null,
  "finished": "1601145004",
  "id": 7,
  "lax": 0,
  "notes": {},
  "parents": [],
  "priority": 0,
  "queue": "default",
  "result": {
    "id": "75d18ce470dc99f83dc355bdad66319d1f33c82b",
    "message": "This file already exists in the Library.",
    "success": 0
  },
  "retried": null,
  "retries": 0,
  "started": "1601145004",
  "state": "finished",
  "task": "handle_upload",
  "time": "1601145005",
  "worker": 1
}
```  

{% endapi-method-response-example %}
{% endapi-method-response %}
{% endapi-method-spec %}
{% endapi-method %}
