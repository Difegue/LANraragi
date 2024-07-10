---
description: Blacklist or rewrite tags the way you want
---

# 📏 Tag Rules

_Tag Rules_ allow you to write rules that will extend the basic functionality of automatic tagging. The rules will be applied to the list of tags returned by the plugins in order to filter or rewrite the tags based on your tastes.

_Tag Rules_ must be written one rule per line, without "_comma_" or "_semicolon_" unless they are part of the tag.

The format is as follows:

* `tag | -tag` : removes the tag
* `-namespace:*` : removes all tags within this namespace
* `~namespace` : strips the namespace from the tags
* `tag -> new-tag` : replaces one tag
* `tag => new-tag` : replaces one tag, but uses a hash table internally for faster performance. These rules will be executed __once__ after all other rules.
* `namespace:* -> new-namespace:*` : replaces the namespace in all tags that contain it

Also note that _the match is case insensitive_, but the replacement will keep the case specified in the rule, so you can write this rule

```
serie:one piece -> parody:One Piece
```

to replace `SERIE:ONE PIECE` with `parody:One Piece`.

## Blacklist

This is the simplest list of rules you can write. Both formats are valid:

```
already uploaded
forbidden content
incomplete
ongoing
complete
various
digital
translated
```

```
-already uploaded
-forbidden content
-incomplete
-ongoing
-complete
-various
-digital
-translated
```

## Advanced usage

Combining the above rules, you can make _LRR_ do some work for you. For example the following set of rules:

```
-already uploaded
-misc:*
serie:* -> parody:*
various -> various artists
~language
```

will transform this tag list

```
already uploaded, misc:ongoing, misc:complete, language:english,
serie:one piece, serie:naruto, various, crossover'
```

in this

```
english, parody:one piece, parody:naruto, various artists, crossover
```
