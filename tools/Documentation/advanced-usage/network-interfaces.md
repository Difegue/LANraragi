# Network Interface Setup

By default, LRR listens on all IPv4 Interfaces on port 3000. To change this, you have to specify a different network location when starting the app.

## Building your network location string

The network location format accepted by LRR looks like this:  
`http(s)://*:(port)`

All listen locations [supported by "listen" in Mojo::Server::Daemon](http://www.mojolicious.org/perldoc/Mojo/Server/Daemon#listen) are valid.

For example, if you want to listen on port 5555 with SSL only, the string would look like:  
`https://*:5555?cert=/path/to/server.crt&key=/path/to/server.key`

Once you have your string ready, the way to give it to the app depends on the install:

## Source Installs

You can change the location by setting it as a parameter of `npm start`:

```bash
npm start http://127.0.0.1:8000

> LANraragi@0.5.0 start /mnt/c/Users/Tamamo/Desktop/lanraragi
> perl ./script/lanraragi daemon -l "http://127.0.0.1:8000"

ｷﾀ━━━━━━(ﾟ∀ﾟ)━━━━━━!!!!!
[LANraragi] LANraragi 0.5.0 (re-)started. (Production Mode)
[...]
[Mojolicious] Listening at "http://127.0.0.1:8000"
```

## Docker

You can set the interface string as a Docker environment variable when building your container off the image.  
We look for the parameter `lrr_network`.

```bash
docker run --name=lanraragi -p 8000:8000 \
--mount type=bind,source=[YOUR_CONTENT_DIRECTORY],\
target=/home/koyomi/lanraragi/content \
-e lrr_network=http://*:8000 difegue/lanraragi
```

