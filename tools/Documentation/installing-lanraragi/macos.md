# 🍎 Homebrew (macOS)

## Migration

To use all your existing files within a brewed LRR, you can issue the following commands:

```bash
lrr="${HOME}/Library/Application Support/LANraragi/"
# if you’re on Linux, use the next line instead:
#lrr="${HOME}/LANraragi/"
cd <LRR folder>
mkdir -p "${lrr}"
mv content "${lrr}/content"
mv log "${lrr}/log"
mv public/temp "${lrr}/temp"
mv database.rdb "${lrr}/database/database.rdb"
```

{% hint style="info" %}
This simply moves all your files to the default location where LRR looks for them when installed with Homebrew. You can do that manually too, if you chose so.
{% endhint %}

If you succeeded in moving, you can proceed to the next step!

## Installation

If you do not have Homebrew installed yet, simply use the command on [their page](https://brew.sh).

The next step is to then install LRR.

```
brew install lanraragi
```

## Configuration

Your content folder is stored by default in `${HOME}/Library/Application Support/LANraragi`.\
The Redis database is stored in `${HOME}/Library/Application Support/LANraragi/database`. The content folder can be moved to any folder you want through the in-app settings page.

## Usage

Once installed, you can get started by running `lanraragi` and opening [http://localhost:3000](http://localhost:3000).

![brew](<../.gitbook/assets/brew (1).jpg>)

To change the default port or add SSL support, see this page:

{% content-ref url="../advanced-usage/network-interfaces.md" %}
[network-interfaces.md](../advanced-usage/network-interfaces.md)
{% endcontent-ref %}

{% hint style="info" %}
By default, LRR listens on all IPv4 Interfaces on port 3000, unsecured HTTP.
{% endhint %}

## Updating

Simply run `brew install lanraragi --HEAD` again to update to the latest version.

{% hint style="warning" %}
The same warning as in the Installation step applies.
{% endhint %}

## Uninstallation

Run `brew remove lanraragi` to uninstall the app.\
Data in the `${HOME}/Library/Application Support/LANraragi` folder is not deleted.
