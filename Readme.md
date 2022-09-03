The `nginx:alpine` Docker container, + the Nginx Amplify agent.

## Why

Nginx last updated their prebuilt Nginx+Amplify container in 2017, and it was based on their Debian container, so it was huge.

## Usage

Provide these two env vars to the container to enable Amplify:

```
API_KEY (from the Amplify dashboard)
AMPLIFY_IMAGENAME (Used to identify this container)
```

See `nginx.conf.example` for an example nginx.conf that provides all needed logs to the Amplify agent, plus continues to output to `stdout`.

Check `docker-compose.yml` for a full working example.

## Simple usage

```
docker run -p 80:80 -e API_KEY=<amplify_api_key> -e AMPLIFY_IMAGENAME=<some_identifier> makeshift27015/nginx-alpine-amplify
```

then head to the [Amplify dashboard](https://amplify.nginx.com/overview/).
