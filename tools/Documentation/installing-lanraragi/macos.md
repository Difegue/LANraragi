# LRR for macOS

## Installing LRR (with Homebrew)

If you do not have Homebrew installed yet, simply use the command on [their page](https://brew.sh/).

The next step is to tap a private tap to then install LRR.

```text
brew tap bl4cc4t/other
brew install lanraragi --HEAD
```

_These steps are likely to be changed in the future._


### Usage

Once installed, you can get started by running `lanraragi` and opening [http://localhost:3000](http://localhost:3000).

To change the default port or add SSL support, see this page:

{% page-ref page="../advanced-usage/network-interfaces.md" %}

{% hint style="info" %}
By default, LRR listens on all IPv4 Interfaces on port 3000, unsecured HTTP.
{% endhint %}


## Installing LRR (manually)

Please refer to [Source Code \(Linux\)](installing-lanraragi/source.md).
