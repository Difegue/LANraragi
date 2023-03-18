# Category API

{% swagger baseUrl="http://lrr.tvc-16.science" path="/api/categories" method="get" summary="Get all categories" %}
{% swagger-description %}
Get all the categories saved on the server.
{% endswagger-description %}

{% swagger-response status="200" description="" %}
```javascript
[
  {
    "archives": [],
    "id": "SET_1589227137",
    "last_used": "1589487499",
    "name": "doujinshi 💦💦💦",
    "pinned": "1",
    "search": "doujinshi"
  },
  {
    "archives": [],
    "id": "SET_1589291510",
    "last_used": "1589487501",
    "name": "All archives by uo denim",
    "pinned": "0",
    "search": "artist:uo denim"
  },
  {
    "archives": [
      "b835f24b953c236b7bbb22414e4f2f1f4b51891a",
      "9ed04c35aa41be137e3e696d2001a2f6d9cbd38d",
      "8b0b6bb3d180eff607c941755695c317570d8449",
      "a5c0958ad25642e2204aff09f2cc8e70870bd81f",
      "32f0edeb5d5b3cf71a02b39279a69d0a903e4aed"
    ],
    "id": "SET_1589493021",
    "last_used": "1589493776",
    "name": "The very best",
    "pinned": "0",
    "search": ""
  }
]
```
{% endswagger-response %}
{% endswagger %}

{% swagger baseUrl="http://lrr.tvc-16.science" path="/api/categories/:id" method="get" summary="Get a single category" %}
{% swagger-description %}
Get the details of the specified category ID.
{% endswagger-description %}

{% swagger-parameter name="id" type="string" required="true" in="path" %}
ID of the Category desired.
{% endswagger-parameter %}

{% swagger-response status="200" description="" %}
```
{
  "archives": [],
  "id": "SET_1613080290",
  "last_used": "1613080930",
  "name": "My great category",
  "pinned": "0",
  "search": ""
}
```
{% endswagger-response %}

{% swagger-response status="400" description="" %}
```
{
  "error": "The given category does not exist.",
  "operation": "get_category",
  "success": 0
}
```
{% endswagger-response %}
{% endswagger %}

{% swagger baseUrl="http://lrr.tvc-16.science" path="/api/categories" method="put" summary="🔑Create a Category" %}
{% swagger-description %}
Create a new Category.
{% endswagger-description %}

{% swagger-parameter name="pinned" type="boolean" required="false" in="query" %}
Add this parameter if you want the created category to be pinned.
{% endswagger-parameter %}

{% swagger-parameter name="search" type="string" required="false" in="query" %}
Matching predicate, if creating a Dynamic Category.
{% endswagger-parameter %}

{% swagger-parameter name="name" type="string" required="true" in="query" %}
Name of the Category.
{% endswagger-parameter %}

{% swagger-response status="200" description="" %}
```
{
  "category_id": "SET_1589383525",
  "operation": "create_category",
  "success": 1
}
```
{% endswagger-response %}

{% swagger-response status="400" description="" %}
```
{
  "error": "Category name not specified.",
  "operation": "create_category",
  "success": 0
}
```
{% endswagger-response %}
{% endswagger %}

{% swagger baseUrl="http://lrr.tvc-16.science" path="/api/categories/:id" method="put" summary="🔑Update a Category" %}
{% swagger-description %}
Modify a Category.
{% endswagger-description %}

{% swagger-parameter name="id" type="string" required="true" in="path" %}
ID of the Category to update.
{% endswagger-parameter %}

{% swagger-parameter name="name" type="string" required="false" in="query" %}
New name of the Category
{% endswagger-parameter %}

{% swagger-parameter name="search" type="string" required="false" in="query" %}
Predicate. Trying to add a predicate to a category that already contains Archives will give you an error.
{% endswagger-parameter %}

{% swagger-parameter name="pinned" type="boolean" required="false" in="query" %}
Add this argument to pin the Category.

\


If you don't, the category will be unpinned on update.
{% endswagger-parameter %}

{% swagger-response status="200" description="" %}
```
{
  "category_id": "SET_1589573608",
  "operation": "update_category",
  "success": 1
}
```
{% endswagger-response %}

{% swagger-response status="400" description="" %}
```
{
  "error": "The given category does not exist.",
  "operation": "update_category",
  "success": 0
}
```
{% endswagger-response %}
{% endswagger %}

{% swagger baseUrl="http://lrr.tvc-16.science" path="/api/categories/:id" method="delete" summary="🔑Delete a Category" %}
{% swagger-description %}
Remove a Category.
{% endswagger-description %}

{% swagger-parameter name="id" type="string" required="true" in="path" %}
ID of the Category to delete.
{% endswagger-parameter %}

{% swagger-response status="200" description="" %}
```
{
  "operation": "delete_category",
  "success": 1
}
```
{% endswagger-response %}
{% endswagger %}

{% swagger baseUrl="http://lrr.tvc-16.science" path="/api/categories/:id/:archive" method="put" summary="🔑Add an Archive to a Category" %}
{% swagger-description %}
Adds the specified Archive ID (see Archive API) to the given Category.
{% endswagger-description %}

{% swagger-parameter name="id" type="string" required="true" in="path" %}
Category ID to add the Archive to.
{% endswagger-parameter %}

{% swagger-parameter name="archive" type="string" required="true" in="path" %}
Archive ID to add.
{% endswagger-parameter %}

{% swagger-response status="200" description="" %}
```
{
  "operation": "add_to_category",
  "success": 1,
  "successMessage": "Added \"Name of archive\" to category \"Name of category\""
}
```
{% endswagger-response %}
{% endswagger %}

{% swagger baseUrl="http://lrr.tvc-16.science" path="/api/categories/:id/:archive" method="delete" summary="🔑Remove an Archive from a Category" %}
{% swagger-description %}
Remove an Archive ID from a Category.
{% endswagger-description %}

{% swagger-parameter name="id" type="string" required="true" in="path" %}
Category ID
{% endswagger-parameter %}

{% swagger-parameter name="archive" type="string" required="true" in="path" %}
Archive ID
{% endswagger-parameter %}

{% swagger-response status="200" description="" %}
```
{
  "operation": "remove_from_category",
  "success": 1
}
```
{% endswagger-response %}
{% endswagger %}
