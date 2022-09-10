# Nginx + Amplify Agent in an Alpine Container

The `nginx:alpine` Docker container, + the Nginx Amplify agent.

## Nginx removed the source for Nginx Amplify

In June 2022, Nginx removed the source from the [nginxinc/nginx-amplify-agent](https://github.com/nginxinc/nginx-amplify-agent) repository for unknown reasons. As such, this container got a little bit more complicated and now has to extract the files from one of their releases, which is a bit annoying. Hopefully they'll reply to [my issue](https://github.com/nginxinc/nginx-amplify-doc/issues/55) to make this simpler.

## Why does this exist

Nginx last updated their prebuilt Nginx+Amplify container in 2017, and it was based on their Debian container, so it was huge. Also, they now only release full packages which are only supported by certain distros, Alpine not included. This fixes that.

This Alpine-based container is quite small and should support the following platforms:

- linux/amd64
- linux/arm/v6
- linux/arm/v7
- linux/arm64/v8
- linux/ppc64le
- linux/s390x

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
