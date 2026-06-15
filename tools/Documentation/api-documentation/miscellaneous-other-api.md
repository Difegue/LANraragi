---
description: Other APIs that don't fit a dedicated theme.
---

# Miscellaneous other API

{% openapi-operation spec="lanraragi-api" path="/info" method="get" %}
[OpenAPI lanraragi-api](https://raw.githubusercontent.com/Difegue/LANraragi/refs/heads/dev/tools/openapi.yaml)
{% endopenapi-operation %}

{% openapi-operation spec="lanraragi-api" path="/server/status" method="get" %}
[OpenAPI lanraragi-api](https://raw.githubusercontent.com/Difegue/LANraragi/refs/heads/dev/tools/openapi.yaml)
{% endopenapi-operation %}

{% openapi-operation spec="lanraragi-api" path="/tempfolder" method="delete" %}
[OpenAPI lanraragi-api](https://raw.githubusercontent.com/Difegue/LANraragi/refs/heads/dev/tools/openapi.yaml)
{% endopenapi-operation %}

{% openapi-operation spec="lanraragi-api" path="/download_url" method="post" %}
[OpenAPI lanraragi-api](https://raw.githubusercontent.com/Difegue/LANraragi/refs/heads/dev/tools/openapi.yaml)
{% endopenapi-operation %}

{% openapi-operation spec="lanraragi-api" path="/regen_thumbs" method="post" %}
[OpenAPI lanraragi-api](https://raw.githubusercontent.com/Difegue/LANraragi/refs/heads/dev/tools/openapi.yaml)
{% endopenapi-operation %}

## Metrics

The `/api/info/metrics` endpoint returns metrics in the [Prometheus exposition format](https://prometheus.io/docs/instrumenting/exposition_formats/#text-format-example).

```sh
# HELP lanraragi_api_requests_total Total number of API requests
# TYPE lanraragi_api_requests_total counter
lanraragi_api_requests_total{endpoint="/",method="GET"} 4063
lanraragi_api_requests_total{endpoint="/api/archives/:id",method="DELETE"} 2
lanraragi_api_requests_total{endpoint="/api/archives/:id/categories",method="GET"} 1
lanraragi_api_requests_total{endpoint="/api/archives/:id/files",method="GET"} 7
lanraragi_api_requests_total{endpoint="/api/archives/:id/files/thumbnails",method="POST"} 5
lanraragi_api_requests_total{endpoint="/api/archives/:id/isnew",method="DELETE"} 7
lanraragi_api_requests_total{endpoint="/api/archives/:id/metadata",method="GET"} 8
# ...
```

