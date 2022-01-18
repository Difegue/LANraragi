---
description: Control the built-in Minion Job Queue.
---

# Minion API

{% swagger baseUrl="http://lrr.tvc-16.science" path="/api/minion/:jobid" method="get" summary="Get the basic status of a Minion Job" %}
{% swagger-description %}
For a given Minion job ID, check whether it succeeded or failed.  
Minion jobs are ran for various occasions like thumbnails, cache warmup and handling incoming files.  
{% endswagger-description %}

{% swagger-parameter name="id" type="string" required="true" in="path" %}
ID of the Job.
{% endswagger-parameter %}

{% swagger-response status="200" description="You get job data." %}
```javascript
{
  "state": "finished",
  "task": "handle_upload",
  "error": null
}

{
  "state": "failed",
  "task": "thumbnail_task",
  "error": "oh no"
}
```
{% endswagger-response %}
{% endswagger %}

{% swagger baseUrl="http://lrr.tvc-16.science" path="/api/minion/:jobid/detail" method="get" summary="🔑Get the full status of a Minion Job" %}
{% swagger-description %}
Get the status of a Minion Job. 
This API is there for internal usage mostly, but you can use it to get detailed status for jobs like plugin runs or URL downloads.
{% endswagger-description %}

{% swagger-parameter name="id" type="string" required="true" in="path" %}
ID of the Job.
{% endswagger-parameter %}

{% swagger-response status="200" description="You get detailed job data." %}
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
{% endswagger-response %}
{% endswagger %}


