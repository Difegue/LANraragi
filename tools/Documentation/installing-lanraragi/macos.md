# Homebrew \(macOS/Linux\)

## Installation

If you do not have Homebrew installed yet, simply use the command on [their page](https://brew.sh/).

The next step is to tap a private tap to then install LRR.

```text
brew tap bl4cc4t/other
brew install lanraragi --HEAD
```

{% hint style="warning" %}
Currently, doing a homebrew install will use the latest commit from the `dev` branch -- Aka a nightly.  
This step will change soon with the release of v.0.6.6.  
{% endhint %}  

## Configuration

The Redis database and your content folder are stored by default in `${HOME}/Library/Application Support/LANraragi`.  
The content folder can be moved to any folder you want through the in-app settings page.  

## Usage

Once installed, you can get started by running `lanraragi` and opening [http://localhost:3000](http://localhost:3000).

![brew](../.gitbook/assets/brew.jpg)  

To change the default port or add SSL support, see this page:

{% page-ref page="../advanced-usage/network-interfaces.md" %}

{% hint style="info" %}
By default, LRR listens on all IPv4 Interfaces on port 3000, unsecured HTTP.
{% endhint %}

## Updating  

Simply run `brew install lanraragi --HEAD` again to update to the latest version.  

{% hint style="warning" %}
The same warning as in the Installation step applies.  
{% endhint %}  

## Uninstallation  

Run `brew remove lanraragi` to uninstall the app.  
Data in the `${HOME}/Library/Application Support/LANraragi` folder is not deleted.