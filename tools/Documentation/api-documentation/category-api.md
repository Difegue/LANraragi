# Category API

{% api-method method="get" host="http://lrr.tvc-16.science" path="/api/categories" %}
{% api-method-summary %}
Get all categories
{% endapi-method-summary %}

{% api-method-description %}
Get all the categories saved on the server.
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}
{% endapi-method-request %}
{% api-method-response %}
{% api-method-response-example httpCode=200 %}
{% api-method-response-example-description %}
You get the categories. The "id" parameter is to be used in the next endpoints.
{% endapi-method-response-example-description %}

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
{% endapi-method-response-example %}
{% endapi-method-response %}
{% endapi-method-spec %}
{% endapi-method %}

{% api-method method="get" host="http://lrr.tvc-16.science" path="/api/categories/:id" %}
{% api-method-summary %}
Get a single category
{% endapi-method-summary %}

{% api-method-description %}
Get the details of the specified category ID.
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}
{% api-method-path-parameters %}
{% api-method-parameter name="id" type="string" required=true %}
ID of the Category desired.
{% endapi-method-parameter %}
{% endapi-method-path-parameters %}
{% endapi-method-request %}

{% api-method-response %}
{% api-method-response-example httpCode=200 %}
{% api-method-response-example-description %}
You get category info.
{% endapi-method-response-example-description %}

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
{% endapi-method-response-example %}

{% api-method-response-example httpCode=400 %}
{% api-method-response-example-description %}
The ID you've specified doesn't exist.
{% endapi-method-response-example-description %}

```
{
  "error": "The given category does not exist.",
  "operation": "get_category",
  "success": 0
}
```
{% endapi-method-response-example %}
{% endapi-method-response %}
{% endapi-method-spec %}
{% endapi-method %}


{% api-method method="put" host="http://lrr.tvc-16.science" path="/api/categories" %}
{% api-method-summary %}
🔑Create a Category
{% endapi-method-summary %}

{% api-method-description %}
Create a new Category.
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}
{% api-method-query-parameters %}
{% api-method-parameter name="pinned" type="boolean" required=false %}
Add this parameter if you want the created category to be pinned.
{% endapi-method-parameter %}

{% api-method-parameter name="search" type="string" required=false %}
Matching predicate, if creating a Dynamic Category.
{% endapi-method-parameter %}

{% api-method-parameter name="name" type="string" required=true %}
Name of the Category.
{% endapi-method-parameter %}
{% endapi-method-query-parameters %}
{% endapi-method-request %}

{% api-method-response %}
{% api-method-response-example httpCode=200 %}
{% api-method-response-example-description %}
The category is successfully created.
{% endapi-method-response-example-description %}

```
{
  "category_id": "SET_1589383525",
  "operation": "create_category",
  "success": 1
}
```
{% endapi-method-response-example %}

{% api-method-response-example httpCode=400 %}
{% api-method-response-example-description %}
You did not specify a category name.
{% endapi-method-response-example-description %}

```
{
  "error": "Category name not specified.",
  "operation": "create_category",
  "success": 0
}
```
{% endapi-method-response-example %}
{% endapi-method-response %}
{% endapi-method-spec %}
{% endapi-method %}

{% api-method method="put" host="http://lrr.tvc-16.science" path="/api/categories/:id" %}
{% api-method-summary %}
🔑Update a Category
{% endapi-method-summary %}

{% api-method-description %}
Modify a Category.
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}
{% api-method-path-parameters %}
{% api-method-parameter name="id" type="string" required=true %}
ID of the Category to update.
{% endapi-method-parameter %}
{% endapi-method-path-parameters %}

{% api-method-query-parameters %}
{% api-method-parameter name="name" type="string" required=false %}
New name of the Category
{% endapi-method-parameter %}

{% api-method-parameter name="search" type="string" required=false %}
Predicate. Trying to add a predicate to a category that already contains Archives will give you an error.
{% endapi-method-parameter %}

{% api-method-parameter name="pinned" type="boolean" required=false %}
Add this argument to pin the Category.   
If you don't, the category will be unpinned on update.
{% endapi-method-parameter %}
{% endapi-method-query-parameters %}
{% endapi-method-request %}

{% api-method-response %}
{% api-method-response-example httpCode=200 %}
{% api-method-response-example-description %}
The category is updated with the specified info.
{% endapi-method-response-example-description %}

```
{
  "category_id": "SET_1589573608",
  "operation": "update_category",
  "success": 1
}
```
{% endapi-method-response-example %}

{% api-method-response-example httpCode=400 %}
{% api-method-response-example-description %}
The ID you've specified doesn't exist.
{% endapi-method-response-example-description %}

```
{
  "error": "The given category does not exist.",
  "operation": "update_category",
  "success": 0
}
```
{% endapi-method-response-example %}
{% endapi-method-response %}
{% endapi-method-spec %}
{% endapi-method %}

{% api-method method="delete" host="http://lrr.tvc-16.science" path="/api/categories/:id" %}
{% api-method-summary %}
🔑Delete a Category
{% endapi-method-summary %}

{% api-method-description %}
Remove a Category.
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}
{% api-method-path-parameters %}
{% api-method-parameter name="id" type="string" required=true %}
ID of the Category to delete.
{% endapi-method-parameter %}
{% endapi-method-path-parameters %}
{% endapi-method-request %}

{% api-method-response %}
{% api-method-response-example httpCode=200 %}
{% api-method-response-example-description %}
The Category is deleted. This endpoint doesn't return error codes for the time being.
{% endapi-method-response-example-description %}

```
{
  "operation": "delete_category",
  "success": 1
}
```
{% endapi-method-response-example %}
{% endapi-method-response %}
{% endapi-method-spec %}
{% endapi-method %}

{% api-method method="put" host="http://lrr.tvc-16.science" path="/api/categories/:id/:archive" %}
{% api-method-summary %}
🔑Add an Archive to a Category
{% endapi-method-summary %}

{% api-method-description %}
Adds the specified Archive ID \(see Archive API\) to the given Category.
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}
{% api-method-path-parameters %}
{% api-method-parameter name="id" type="string" required=true %}
Category ID to add the Archive to.
{% endapi-method-parameter %}

{% api-method-parameter name="archive" type="string" required=true %}
Archive ID to add.
{% endapi-method-parameter %}
{% endapi-method-path-parameters %}
{% endapi-method-request %}

{% api-method-response %}
{% api-method-response-example httpCode=200 %}
{% api-method-response-example-description %}
Archive is added. This endpoint doesn't return error codes for the time being.
{% endapi-method-response-example-description %}

```
{
  "operation": "add_to_category",
  "success": 1
}
```
{% endapi-method-response-example %}
{% endapi-method-response %}
{% endapi-method-spec %}
{% endapi-method %}

{% api-method method="delete" host="http://lrr.tvc-16.science" path="/api/categories/:id/:archive" %}
{% api-method-summary %}
🔑Remove an Archive from a Category
{% endapi-method-summary %}

{% api-method-description %}
Remove an Archive ID from a Category.
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}
{% api-method-path-parameters %}
{% api-method-parameter name="id" type="string" required=true %}
Category ID
{% endapi-method-parameter %}

{% api-method-parameter name="archive" type="string" required=true %}
Archive ID
{% endapi-method-parameter %}
{% endapi-method-path-parameters %}
{% endapi-method-request %}

{% api-method-response %}
{% api-method-response-example httpCode=200 %}
{% api-method-response-example-description %}
The archive is removed from the category. This endpoint doesn't return error codes for the time being.
{% endapi-method-response-example-description %}

```
{
  "operation": "remove_from_category",
  "success": 1
}
```
{% endapi-method-response-example %}
{% endapi-method-response %}
{% endapi-method-spec %}
{% endapi-method %}

