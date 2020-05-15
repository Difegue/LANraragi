---
description: Control the built-in Background Worker.
---

# Shinobu API

{% api-method method="get" host="http://lrr.tvc-16.science" path="/api/shinobu" %}
{% api-method-summary %}
🔑Get Shinobu Status
{% endapi-method-summary %}

{% api-method-description %}
Get the current status of the Worker.
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}

{% api-method-response %}
{% api-method-response-example httpCode=200 %}
{% api-method-response-example-description %}
Get the Shinobu process PID, and whether or not it's alive.
{% endapi-method-response-example-description %}

```javascript
{
  "is_alive": 1,
  "operation": "shinobu_status",
  "pid": 1608
}
```
{% endapi-method-response-example %}
{% endapi-method-response %}
{% endapi-method-spec %}
{% endapi-method %}

{% api-method method="post" host="http://lrr.tvc-16.science" path="/api/shinobu/stop" %}
{% api-method-summary %}
🔑Stop Shinobu
{% endapi-method-summary %}

{% api-method-description %}
Stop the Worker.
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}

{% api-method-response %}
{% api-method-response-example httpCode=200 %}
{% api-method-response-example-description %}
Worker is killed.
{% endapi-method-response-example-description %}

```javascript
{
  "operation": "shinobu_stop",
  "success": 1
}
```
{% endapi-method-response-example %}
{% endapi-method-response %}
{% endapi-method-spec %}
{% endapi-method %}

{% api-method method="post" host="http://lrr.tvc-16.science" path="/api/shinobu/restart" %}
{% api-method-summary %}
🔑Restart Shinobu
{% endapi-method-summary %}

{% api-method-description %}
\(Re\)-start the Worker.
{% endapi-method-description %}

{% api-method-spec %}
{% api-method-request %}

{% api-method-response %}
{% api-method-response-example httpCode=200 %}
{% api-method-response-example-description %}
Worker is started with a new PID.
{% endapi-method-response-example-description %}

```javascript
{
  "new_pid": 1727,
  "operation": "shinobu_restart",
  "success": 1
}
```
{% endapi-method-response-example %}
{% endapi-method-response %}
{% endapi-method-spec %}
{% endapi-method %}

