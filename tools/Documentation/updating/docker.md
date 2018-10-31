## Docker

As Docker containers are immutable, you need to destroy your existing container and build a new one.
```
docker pull difegue/lanraragi
docker stop lanraragi
docker rm lanraragi
docker run --name=lanraragi -p 3000:3000 --mount type=bind,source=[YOUR_CONTENT_DIRECTORY],target=/home/koyomi/lanraragi/content difegue/lanraragi
```  
As long as you use the same content directory as the mount source, your data will still be there.

**Hot Tip** : If you update often, you might want to consider using [portainer](https://portainer.io/) to redeploy containers without entering the entire configuration every time.
