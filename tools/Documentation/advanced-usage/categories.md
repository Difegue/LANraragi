---
description: Organize your archives in dynamic or static categories.
---

# 📂 Categories

Categories appear in the archive index as shortcut buttons.

![Example categories](<../.screenshots/favtags.jpg>)

There are two distinct kinds:

* 📁 Static Categories are arbitrary collections of Archives, where you can add as many items as you want.
* ⚡ Dynamic Categories contain all archives matching a given predicate, and automatically update alongside your library.

Toggling a category in the index will restrict all your searches to that category, for as long as it is toggled. If you have a lot of categories, the most recently used will appear first in the list.  
**📌Pinned** Categories will always show first.

![filtered](../.screenshots/category\_filtered.png)

To create categories, you can use the dedicated setting page in the app:

![Category creation page](../.screenshots/categories.png)

{% hint style="info" %}
If you have an existing folder hierarchy for your Archives, LRR can automatically create categories from said hierarchy through the dedicated utility Script.

Look for it in Plugin Configuration.
{% endhint %}

## 🔖 Bookmark Feature

LANraragi includes a bookmark feature that provides a quick way to add or remove archives from a designated static category. In new installations, a "Favorites" static category is automatically created and linked to this feature.

When enabled, a bookmark icon appears next to all archive thumbnails on the homepage and in the reader interface. Clicking this icon instantly adds or removes the archive from the linked category, making content curation faster and more convenient.

![Bookmark icon](../.screenshots/bookmark\_button.png)

You can link the bookmark feature to any static category of your choice. To change which category is used, navigate to the Category Management page, select the desired static category, and enable the "Link Bookmark Icon to this Category" toggle.

{% hint style="info" %}
Only static categories can be linked to the bookmark feature. Dynamic categories (those based on search predicates) cannot be used with this feature.
{% endhint %}

To disable the bookmark feature entirely, simply toggle off the "Link Bookmark Icon to this Category" option for the currently linked category.

![Bookmark configuration toggle](../.screenshots/bookmark\_config.png)

{% hint style="info" %}
If you delete a category that is currently linked to the bookmark feature, the bookmark functionality will be automatically disabled.
{% endhint %}