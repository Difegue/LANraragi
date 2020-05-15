# Miscellaneous other API

{% api-method method="get" host="http://lrr.tvc-16.science" path="/api/opds" %}
{% api-method-summary %}
Get the OPDS Catalog
{% endapi-method-summary %}

{% api-method-description %}
Get the Archive Index as an OPDS 1.2 Catalog.
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}
{% api-method-path-parameters %}
{% api-method-parameter name="id" type="string" required=false %}
ID of an archive. Passing this will show only one `<entry\>` for the given ID in the result, instead of all the archives.
{% endapi-method-parameter %}
{% endapi-method-path-parameters %}
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
{% endapi-method-response %}
{% endapi-method-spec %}
{% endapi-method %}

{% api-method method="post" host="http://lrr.tvc-16.science" path="/api/plugin/use" %}
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

{% api-method-response %}
{% api-method-response-example httpCode=200 %}
{% api-method-response-example-description %}
Temporary folder is deleted.
{% endapi-method-response-example-description %}

```
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

