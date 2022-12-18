# 🔎 Searching the Archive Index

The search bar in LANraragi tries to not be too dumb and will actively suggest tags to you as you type.

![Search suggestions](../.screenshots/search.png)

If you want to queue multiple terms/tags, you have to use **commas** to separate them, much like how tags are entered in the metadata field when editing an archive.  
You can mix both tags and a specific title in a search if you want.  

You can also use the following special characters in a search:

**Quotation Marks ("...")**\
Exact string search. Everything placed inside a pair of quotation marks is treated as a singular term. Wildcard characters are still interpreted as wildcards.

**Question Mark (?), Underscore (\_)**\
Wildcard. Can match any single character.

**Asterisk (\*), Percentage Sign (%)**\
Wildcard. Can match any sequence of characters (including none).

**Subtraction Sign (-)**\
Exclusion. When placed before a term, prevents search results from including that term.

**Dollar Sign ($)**\
Add at the end of a tag to perform an exact tag search rather than displaying all elements that start with the term. Can be used as an exclusion to ignore misc tags in the search query.
