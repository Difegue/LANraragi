# Network Interface Setup

By default, LRR listens on all IPv4 Interfaces on port 3000. To change this, you have to specify a different network location when starting the app.

## Building your network location string

The network location format accepted by LRR looks like this:  
`http(s)://*:(port)`

All listen locations [supported by "listen" in Mojo::Server::Daemon](http://www.mojolicious.org/perldoc/Mojo/Server/Daemon#listen) are valid.

For example, if you want to listen on port 5555 with SSL only, the string would look like:  
`https://*:5555?cert=/path/to/server.crt&key=/path/to/server.key`

Once you have your string ready, you can assign it to the environment variable `LRR_NETWORK`. It'll be picked up automagically.

{% hint style="info" %}
If you're using Docker, remember to mount your cert and keys to a path reachable by the container:  
The arguments above will resolve within the container's filesystem!
{% endhint %}

## Source Installs

```bash
export LRR_NETWORK=http://127.0.0.1:8000
npm start

> lanraragi@0.6.0 start /mnt/c/Users/tiki/Desktop/lrr
> perl ./script/launcher.pl -f ./script/lanraragi

ｷﾀ━━━━━━(ﾟ∀ﾟ)━━━━━━!!!!!
[LANraragi] [info] LANraragi 0.6.0-BETA.2 (re-)started. (Debug Mode)
[...]
[Mojolicious] Listening at "http://127.0.0.1:8000"
Server available at http://127.0.0.1:8000
```

## Docker

```bash
docker run --name=lanraragi -p 8000:8000 \
--mount type=bind,source=[YOUR_CONTENT_DIRECTORY],\
target=/home/koyomi/lanraragi/content \
-e LRR_NETWORK=http://*:8000 difegue/lanraragi
```

## Docker with SSL

```bash
docker run --name=lanraragi-ssl -p 3333:3333 \
--mount type=bind,source=[YOUR_CONTENT_DIRECTORY],\
target=/home/koyomi/lanraragi/content \
--mount type=bind,source=[DIRECTORY_CONTAINING_SSL_CERT],target=/ssl \
-e LRR_NETWORK="https://*:3333?cert=/ssl/crt.crt&key=/ssl/crt.key" difegue/lanraragi
```

Notice that the certificate and key must come from your host filesystem and henceforth might need a second --mount command.

