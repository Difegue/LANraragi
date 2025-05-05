---
description: Details on making additional translations for the server's Web UI.
---

# 🈁 Translating LANraragi to other languages

LRR will automatically render its web UI in the language requested by your web browser's `Accept-Language` header, if it supports it.  
Unsupported languages will fallback to English.  

Here are some pointers on contributing additional translations to LANraragi.  
LRR uses standard `.po` files to contain its localizations.  

## Using Weblate 
You can easily contribute to translations to existing or new languages through LRR's Weblate project:  
https://hosted.weblate.org/projects/lanraragi/lanraragi-source/  

Strings submitted to Weblate will be automatically commited to a PR against the base LANraragi GitHub repository.  

## Translate text in-source 
First, open the `locales\template` folder where you will see the current translation files.  
It's recommended to use the `en.po` file as your base for translation.

Next, make a copy of `en.po` and rename it to the language you wish to translate into, for example, `zh.po`. Then, open the `zh.po` file.

There, you will see something like this:

```
# Sample Data
msgid ""
msgstr ""

# ------Start of Backup.html.tt2------
msgid "Database Backup/Restore"
msgstr "Database Backup/Restore"

msgid "You can backup your existing database here, or restore an existing backup."
msgstr "You can backup your existing database here, or restore an existing backup."

...
```

For translation purposes, you need only modify the content in `msgstr`. For instance, if you are translating from English to Chinese, you would replace the English in `msgstr` with the corresponding Chinese. For example:
`msgstr "Database Backup/Restore"` becomes `msgstr "数据库备份/恢复"`.

Continue translating the text within `msgstr` into your language, and that will complete the translation of the text within LANraragi's templates!

Here are a few points you might need to pay attention to:

1. Some translation texts include HTML styles. It's advisable not to remove these styles; instead, match the styles with your translated text accordingly.

2. Some translation files contain placeholders. It's crucial not to delete these placeholders. Only translate the content excluding placeholders and then position the placeholders appropriately. For example:
   `msgstr "Version %1 %2"` should become `msgstr "版本 %1 %2"`.

3. Due to the limitations of `Locale::Maketext`, some special texts require special handling. Currently, there's one known special case:
   `msgstr "<b>~namespace</b> : strips the namespace from the tags"`
   Make sure not to discard the `~` when you see the `msgid` for `msgid "namespace : strips the namespace from the tags"`, because `~` is recognized as an escape character in `Locale::Maketext` (though attempts to use `~~` haven't been successfully recognized).


## Handling missing translations 

If you notice that some texts are missing translations in the relevant `template` files,  
here is a step-by-step example of how to address this:  

### HTML 

For instance, see the following code in your `index.html.tt2` template:  
```html
<a href="[% c.url_for("/upload") %]">Add Archives</a>
```

To handle the missing translation, wrap the text with `[% c.lh("...text to be handled...") %]` like this:
```html
<a href="[% c.url_for("/upload") %]">[% c.lh("Add Archives") %]</a>
```

### Javascript 

For JS text, you need to replace your hard-coded string with a `I18N.xxxxx` variable/function. For example:  

```javascript
   $("#result").html("Backup failed!");
```
will become  
```javascript
   $("#result").html(I18N.BackupFailed);
```  
Then, modify the `i18n.html.tt2` file to include your new variable/function.  
```
I18N.BackupFailed = "[% c.lh("Backup failed!") %]";  
```  

### Modifying the .po file  

Locate `# ------Start of xxxxx.html.tt2------` in the `en.po` file (with xxxxx being either index or i18n in this example), 
which marks where the corresponding text in the template begins. Add the following entries:  

```
msgid "Add Archives"
msgstr "Add Archives"

msgid "Backup failed!"
msgid "Backup failed!"
```  

Here, `msgid` is used to match the text, and `msgstr` contains the translated text.  

It is crucial to ensure that the text in `msgid` is exactly as it appears post-modification in your template to ensure proper matching. For example, the code below includes an extra space, causing a mismatch which prevents it from being replaced correctly:

```html
<a href="[% c.url_for("/upload") %]">[% c.lh("Add Archives ") %]</a>
```

### Placeholders (HTML)  

For special cases, like in `config.html.tt2`, which looks like this:

```html
<h1 style="margin-bottom: 2px">LANraragi</h1>
Version [% version %], "[% vername %]"
<br>
```  

You'll need to use placeholders:

```html
<h1 style="margin-bottom: 2px">LANraragi</h1>
[% c.lh("Version [_1] [_2]", version, vername) %]
<br>
```

In translation files, HTML placeholders should be written as `%number` instead of `[_number]` used in templates. Therefore, it should be:

```
msgid "Version %1 %2"
msgstr "Version %1 %2"
```

### Placeholders (Javascript)

For **Javascript**, placeholders instead need to be written like the following:  

```
msgid "Changed title to: \${title}"
msgstr "Changed title to: ${title}"
```  
Pay attention to the slash only being present in the msgid.  

Then, your entry in `i18n.html.tt2` needs to be modified to accomodate for the placeholders being passed at runtime by using a function instead of a constant:  
```javascript
I18N.BatchChangedTitle = (title) => `[% c.lh("Changed title to: \${title}") %]`;
```  
and is used like so:  
```javascript
$("#log-container").append(I18N.BatchChangedTitle(msg.title));
```

### Special cases  

There are also peculiar cases such as the following found in `config_tags.html.tt2`:

```html
<br><b>~namespace</b> : strips the namespace from the tags
```

Here, `~` is a designated escape character in `Locale::Maketext`, so including a `~` in `msgid` will prevent proper matching. However, including `~` in `msgstr` won't affect functionality, thus it's preferable to remember this nuance:

```
msgid "namespace : strips the namespace from the tags"
msgstr "<b>~namespace</b> : strips the namespace from the tags"
```

