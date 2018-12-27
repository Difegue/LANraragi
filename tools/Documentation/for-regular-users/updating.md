---
description: Make sure to read the changelog before updating to a new release!
---

# Updating LANraragi

## Update a Docker Installation

As Docker containers are immutable, you need to destroy your existing container and build a new one.

```bash
docker pull difegue/lanraragi
docker stop lanraragi
docker rm lanraragi
docker run --name=lanraragi -p 3000:3000 --mount type=bind,source=[YOUR_CONTENT_DIRECTORY],target=/home/koyomi/lanraragi/content difegue/lanraragi
```

As long as you use the same content directory as the mount source, your data will still be there.

{% hint style="info" %}
If you update often, you might want to consider using [Portainer](https://portainer.io/) to redeploy containers without entering the entire configuration every time.
{% endhint %}

## Update a Vagrant Installation

From the directory where the Vagrantfile is located:

```bash
vagrant up
vagrant provision
```

Those two commands will update the wrapped Docker image to the latest one\(basically automatically doing the commands written up there on the Docker section\). No other operations are needed.

## Update a Windows QuickStarter Install

Simply overwrite your previous QuickStarter folder with the new one.

{% hint style="danger" %}
Do **not** delete the database \(dump.rdb\) or the content folder!
{% endhint %}

## Update a source install

Getting all the files from the latest release and pasting them in the directory of the application should give you a painless update 95% of the time.

To be on the safe side, make sure to rerun the installer once this is done:

```bash
npm run lanraragi-installer install-full
```

