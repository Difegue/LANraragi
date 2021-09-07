---
description: 'Blacklist or rewrite tags the way you want'
---

# Tag Rules

*Tag Rules* allow you to write rules that will extend the basic functionality of automatic tagging.
The rules will be applied to the list of tags returned by the plugins in order to filter or rewrite the tags based on your tastes.

*Tag Rules* must be written one rule per line, without "*comma*" or "*semicolon*" unless they are part of the tag.

The format is as follows:

- `tag | -tag` : removes the tag
- `-namespace:*` : removes all tags within this namespace
- `~namespace` : strips the namespace from the tags
- `tag -> new-tag` : replaces one tag
- `namespace:* -> new-namespace:*` : replaces the namespace in all tags that contain it

Also note that *the match is case insensitive*, but the replacement will keep the case specified in the rule, so you can write this rule

```txt
serie:one piece -> parody:One Piece
```

to replace `SERIE:ONE PIECE` with `parody:One Piece`.

## Blacklist

This is the simplest list of rules you can write. Both formats are valid:

```txt
already uploaded
forbidden content
incomplete
ongoing
complete
various
digital
translated
```

```txt
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

Combining the above rules, you can make *LRR* do some work for you. For example the following set of rules:

```txt
-already uploaded
-misc:*
serie:* -> parody:*
various -> various artists
~language
```

will transform this tag list

```txt
already uploaded, misc:ongoing, misc:complete, language:english,
serie:one piece, serie:naruto, various, crossover'
```

in this

```txt
english, parody:one piece, parody:naruto, various artists, crossover
```
