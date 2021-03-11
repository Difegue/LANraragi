---
description: >-
  Docker is the best way to install the software on remote servers. I don't
  recommand it for Desktop machines and casual users due to it being a bit
  complex to wield.
---

# Docker \(All platforms\)

A Docker image exists for deploying LANraragi installs to your machine easily without disrupting your already-existing web server setup.  
Docker is the best way to install the software on remote servers. I don't recommand it for Desktop machines and casual users due to it being a bit complex to wield.

## Cloning the base LRR image

Download [the Docker setup](https://www.docker.com/products/docker) and install it. Once you're done, execute:

```bash
docker run --name=lanraragi -p 3000:3000 \
--mount type=bind,source=[YOUR_CONTENT_DIRECTORY],target=/home/koyomi/lanraragi/content \
--mount type=bind,source=[YOUR_DATABASE_DIRECTORY],target=/home/koyomi/lanraragi/database \
difegue/lanraragi
```

{% hint style="warning" %}
If your Docker version is [_below 17.06_](https://docs.docker.com/storage/bind-mounts/) and you use the --mount option as listed above, you will get the following error:

```bash
unknown flag: --mount 
See 'docker run --help'.
```

You can bypass this issue by using the --volume option for bind-mounting like so:

```bash
docker run --name=lanraragi -p 3000:3000 \
--volume [YOUR_CONTENT_DIRECTORY]:/home/koyomi/lanraragi/content \
--volume [YOUR_CONTENT_DIRECTORY]:/home/koyomi/lanraragi/database \
difegue/lanraragi
```
{% endhint %}

{% hint style="info" %}
You can tell Docker to auto-restart the LRR container on boot by adding the `--restart always` flag to this command.
{% endhint %}

{% hint style="warning" %}
If you're running on Windows, please check the syntax for mapping your content directory [here](https://docs.docker.com/docker-for-windows/#shared-drives).

Windows 7/8 users running the Legacy Docker toolbox will have to explicitly forward port 127.0.0.1:3000 from the host to the container in order to be able to access the app.
{% endhint %}

The content directory you have to specify in the command above will contain archives you either upload through the software or directly drop in, alongside generated thumbnails.  
The database directory houses the LANraragi database\(As database.rdb\), allowing you to hotswap containers without losing any data.

{% hint style="info" %}
You can also mount the database directory to a dedicated Docker volume:

```bash
docker volume create lrr-database
docker run --name=lanraragi -p 3000:3000 \
--mount type=bind,source=[YOUR_CONTENT_DIRECTORY],target=/home/koyomi/lanraragi/content \
--mount source=lrr-database,target=/home/koyomi/lanraragi/database \
difegue/lanraragi
```

The volume can be reused when updating, so your database will still follow along even if the container is destroyed.  
You can always backup the database using LANraragi's internal tool.
{% endhint %}

Once your LANraragi container is loaded, you can access it at [http://localhost:3000](http://localhost:3000) .  
You can use the following commands to stop/start/remove the container\(Removing it won't delete the archive directory you specified\) :

```bash
docker stop lanraragi
docker start lanraragi
docker rm lanraragi
```

[Tags](https://hub.docker.com/r/difegue/lanraragi/tags/) exist for major releases, so you can use those if you want to run another version:  
`docker run [yadda yadda] difegue/lanraragi:0.4.0`

{% hint style="danger" %}
If you're feeling **extra dangerous**, you can run the last files directly from the _dev_ branch of the Git repo through the _nightly_ tag:  
`docker run [zoinks] difegue/lanraragi:nightly`
{% endhint %}

## Changing the port

Since Docker allows for port mapping, you can most of times map the default port of 3000 to another port on your host quickly.  
If you need something a bit more involved \(like adding SSL\), please check the Network Interfaces section for how to use thhe `LRR_NETWORK` environment variable.

{% page-ref page="../advanced-usage/network-interfaces.md" %}

{% hint style="info" %}
The default healthchecks of the Docker container base themselves on port 3000.  
If you use the LRR\_NETWORK variable to change the outgoing port instead of Docker's port mapping, said healthchecks will fail.  
If you have to use the variable for SSL or the like, I recommend leaving the port in it to 3000 and doing your port mapping on the Docker side.
{% endhint %}

## Changing the user ID in case of permission issues

The container runs the software by default using the uid/gid provided by the LRR\_UID/LRR\_GID variables.  
If you don't specify said variables, the container will run under uid/gid 9001/9001.

This is good enough for most scenarios, but in case you need to run it as the current user, you can do the following: ```docker run [wassup] -e LRR_UID=``id -u $USER`` -e LRR_GID=``id -g $USER`` difegue/lanraragi```

This uses `id` to automatically fetch your userid/groupid.

## Updating

As Docker containers are immutable, you need to destroy your existing container and build a new one.

```bash
docker pull difegue/lanraragi
docker stop lanraragi
docker rm lanraragi
docker run --name=lanraragi -p 3000:3000 --mount type=bind,source=[YOUR_CONTENT_DIRECTORY],target=/home/koyomi/lanraragi/content difegue/lanraragi
```

As long as you use the same content directory as the mount source, your data will still be there.

{% hint style="info" %}
If you update often, you might want to consider using docker-compose or [Portainer](https://portainer.io/) to redeploy containers without entering the entire configuration every time.
{% endhint %}

## Building your own

The previous setup gets a working LANraragi container from the Docker Hub, but you can build your own bleeding edge version by executing `npm run docker-build` from a cloned Git repo.

This will use your cloned Git repo to build the image, modifications you might have made included.

Of course, this requires a Docker installation.  
If you're running WSL1, which can't run Docker natively, you can directly use the Docker for Windows executable with a simple symlink:

```bash
sudo ln -s '/mnt/c/Program Files/Docker/Docker/resources/bin/docker.exe' \
/usr/local/bin/docker
```

