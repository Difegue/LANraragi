---
description: Configure registries and install plugins
---

# 📦 Plugin Registries

*Plugin registries* allow you to extend LRR's capabilities through third-party plugins.

{% hint style="warning" %}
Currently registry and managed plugin operations are only supported through the API.
{% endhint %}

## Adding a Registry

Three types of registries are supported:

- A **git-based registry** is a git repository on GitHub, or a self-hosted Gitea or Forgejo instance. Configure it with the repository's HTTPS URL, a branch/tag/commit, and the provider (github or gitea).
- A **CDN-based registry** is a folder served on a static file service like nginx. Configure it with the folder's HTTP or HTTPS base URL.
- A **filesystem-based** (local) registry is a folder on disk. Configure it with its absolute path.

A registry's plugins only become available after it is refreshed, which loads its index.

## Plugin Management

Plugins installed through a registry are managed entirely by LRR. Install, upgrade, and uninstall plugins through the plugin API.

<!-- managed plugins -->

## Creating Your Own Registry

A registry must have the following file structure:

```text
|- registry.json
|- artifacts
|  |- plugin-1
      |- 1.0.0
         |- Plugin1.pm
      |- 1.1.0
      |- 2.0.0
      |- ...
|  |- plugin-2
|  |- plugin-3
|  |- ...
```

The `registry.json` holds info about all plugins contained in a registry (you can also generate it with [generate_registry.pl](https://github.com/psilabs-dev/lrr-plugins-demo/blob/main/generate_registry.pl)):

```json
{
    "generated_at": "...",
    "plugins": {
        "sample-downloader" : {
            "namespace" : "plugin-1",
            "type" : "download",
            "versions" : {
                "1.0.0" : {
                "artifact" : "artifacts/plugin-1/1.0.0/Plugin1.pm",
                "author" : "koyomi",
                "description" : "Description for Plugin1",
                "name" : "Plugin 1",
                "published_at" : "2026-05-05T21:31:12Z",
                "sha256" : "b706314ae4800568968e82d248789dc33a705f620283d26c7d13e7ad866aee93",
                "version" : "1.0.0"
                }
            }
        },
        // ...
    }
}
```
