# Table of contents

* [LANraragi Documentation](README.md)

## Installing LANraragi

* [❓ Which installation method is best for me?](installing-lanraragi/methods.md)
* [🪟 LRR for Windows (Win10)](installing-lanraragi/windows.md)
* [🍎 Homebrew (macOS)](installing-lanraragi/macos.md)
* [🐳 Docker (All platforms)](installing-lanraragi/docker.md)
* [🛠️ Source Code (Linux/macOS)](installing-lanraragi/source.md)
* [🐧 Community (Linux)](installing-lanraragi/community.md)
* [👿 Jail (FreeBSD)](installing-lanraragi/jail.md)

## Basic Operations

* [🚀 Getting Started](basic-operations/first-steps.md)
* [📚 Reading Archives](basic-operations/archives.md)
* [✒️ Adding Metadata](basic-operations/metadata.md)
* [🔎 Searching the Archive Index](basic-operations/searching.md)
* [📈 Statistics and Logs](basic-operations/stats.md)
* [🖌️ Themes](basic-operations/themes.md)

## Advanced Usage

* [🦇 Batch Operations](advanced-usage/batch-tagging.md)
* [📂 Categories](advanced-usage/categories.md)
* [⬇️ Downloading Archives](advanced-usage/downloading.md)
* [💾 Backup and Restore](advanced-usage/backup-and-restore.md)
* [📱 Using External Readers](advanced-usage/external-readers.md)
* [🌐 Network Interface Setup](advanced-usage/network-interfaces.md)
* [🕵️ Proxy Setup](advanced-usage/proxy-setup.md)
* [📏 Tag Rules](advanced-usage/tag-rules.md)

## Developer Guide <a href="#extending-lanraragi" id="extending-lanraragi"></a>

* [🏗️ Setup a Development Environment](extending-lanraragi/index.md)
* [🏛️ Architecture & Style](extending-lanraragi/architecture.md)
* [🈁 Translating LANraragi to other languages](extending-lanraragi/translations.md)

## API Documentation

* [🔑 Getting started](api-documentation/getting-started.md)
* [Search API](api-documentation/search-api.md)
* ```yaml
  type: builtin:openapi
  props:
    models: true
    downloadLink: true
  dependencies:
    spec:
      ref:
        kind: openapi
        spec: lanraragi
  ```
* ```yaml
  type: builtin:openapi
  props:
    models: true
    downloadLink: true
  dependencies:
    spec:
      ref:
        kind: openapi
        spec: lanraragi
  ```
* [Archive API](api-documentation/archive-api.md)
* [Database API](api-documentation/database-api.md)
* [Category API](api-documentation/category-api.md)
* [Tankoubon API](api-documentation/tankoubon-api.md)
* [Plugin API](api-documentation/plugin-api.md)
* [Registry API](api-documentation/registry-api.md)
* [Shinobu API](api-documentation/shinobu-api.md)
* [Minion API](api-documentation/minion-api.md)
* [OPDS Catalog](api-documentation/opds-catalog.md)
* [Miscellaneous other API](api-documentation/miscellaneous-other-api.md)

## Writing Plugins <a href="#plugin-docs" id="plugin-docs"></a>

* [🧩 Getting started](plugin-docs/index.md)
* [Login Plugins](plugin-docs/login.md)
* [Metadata Plugins](plugin-docs/metadata.md)
* [Downloader Plugins](plugin-docs/download.md)
* [Generic Plugins ("Scripts")](plugin-docs/scripts.md)
* [Code Examples](plugin-docs/code-examples.md)
