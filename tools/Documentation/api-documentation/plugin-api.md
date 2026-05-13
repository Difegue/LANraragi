---
description: APIs to list and execute Plugins.
---

# Plugin API

{% openapi-operation spec="lanraragi-api" path="/plugins/{type}" method="get" %}
[OpenAPI lanraragi-api](https://raw.githubusercontent.com/Difegue/LANraragi/refs/heads/dev/tools/openapi.yaml)
{% endopenapi-operation %}

{% openapi-operation spec="lanraragi-api" path="/plugins/use" method="post" %}
[OpenAPI lanraragi-api](https://raw.githubusercontent.com/Difegue/LANraragi/refs/heads/dev/tools/openapi.yaml)
{% endopenapi-operation %}

{% openapi-operation spec="lanraragi-api" path="/plugins/queue" method="post" %}
[OpenAPI lanraragi-api](https://raw.githubusercontent.com/Difegue/LANraragi/refs/heads/dev/tools/openapi.yaml)
{% endopenapi-operation %}

{% openapi-operation spec="lanraragi-api" path="/plugins/install" method="post" %}
[OpenAPI lanraragi-api](https://raw.githubusercontent.com/Difegue/LANraragi/refs/heads/dev/tools/openapi.yaml)
{% endopenapi-operation %}

{% openapi-operation spec="lanraragi-api" path="/plugins/installed/{plugin_namespace}" method="delete" %}
[OpenAPI lanraragi-api](https://raw.githubusercontent.com/Difegue/LANraragi/refs/heads/dev/tools/openapi.yaml)
{% endopenapi-operation %}

{% openapi-operation spec="lanraragi-api" path="/plugins/installed/{plugin_namespace}/metadata-config" method="put" %}
[OpenAPI lanraragi-api](https://raw.githubusercontent.com/Difegue/LANraragi/refs/heads/dev/tools/openapi.yaml)
{% endopenapi-operation %}
