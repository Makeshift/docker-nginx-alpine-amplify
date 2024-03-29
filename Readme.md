# Nginx + Amplify Agent in an Alpine Container

The `nginx:alpine` Docker container, + the Nginx Amplify agent. [Amplify](https://amplify.nginx.com/) is Nginx's (currently) free monitoring service for Nginx installations, which shows various stats and can alarm on downtime.

This is a drop-in replacement for the `nginx:alpine` container (including their envsubst stuff), with the Amplify agent installed and ready to go. Simply provide two environment variables, `API_KEY` and `AMPLIFY_IMAGENAME`, and the container will do the rest.

# tl;dr

Repository on [DockerHub](https://hub.docker.com/r/makeshift27015/nginx-alpine-amplify): `makeshift27015/nginx-alpine-amplify`

```properties
docker run -p 80:80 -e API_KEY=<amplify_api_key> -e AMPLIFY_IMAGENAME=<some_identifier> makeshift27015/nginx-alpine-amplify
```

## Nginx removed the source for Nginx Amplify

In June 2022, Nginx removed the source from the [nginxinc/nginx-amplify-agent](https://github.com/nginxinc/nginx-amplify-agent) repository for unknown reasons. As such, this container got a little bit more complicated and now has to extract the files from one of their releases, which is a bit annoying. Hopefully they'll reply to [my issue](https://github.com/nginxinc/nginx-amplify-doc/issues/55) to make this simpler.

## Why does this exist

Nginx last updated their prebuilt [Alpine Nginx+Amplify container](https://github.com/nginxinc/docker-nginx-amplify/) in 2017 (and I literally can't even find it on Docker Hub anymore). It can no longer be built using that repo due to them removing the source from [nginxinc/nginx-amplify-agent](https://github.com/nginxinc/nginx-amplify-agent). They now only release full packages which are only supported by certain distros, Alpine not included. This repo and image fixes that.

This Alpine-based container is reasonably sized at ~131MB, sadly quite a lot larger than the standard `nginx:alpine` (at a slim 22MB). This is largely due to the need for Python and the packages required to get Amplify to run, and I am almost definitely not copying files optimally and would appreciate a PR with advice on it, as my Python skills are lacking.

However, it should support the following platforms:

- linux/amd64 (Confirmed working)
- linux/arm/v6
- linux/arm/v7
- linux/arm64/v8 (Confirmed working)
- linux/ppc64le
- linux/s390x

### Comparison to an 'Official' build

I couldn't find an official build, but assuming you use the base `nginx` image (which is Debian based) on `linux/amd64`, using the official script from [nginxinc/nginx-amplify-agent](https://github.com/nginxinc/nginx-amplify-agent) to install, your Dockerfile ends up looking a bit like this (minus an entrypoint to actually run the agent, additionally this fails because the script immediately tries to use init to start the script, which hangs, and you can't stop it from doing that, _thanks Nginx_, so some hacks are in place):

```dockerfile
FROM nginx
ENV API_KEY=dummy
RUN apt-get update \
  && apt-get -y install python3 gnupg \
  && curl -s https://raw.githubusercontent.com/nginxinc/nginx-amplify-agent/master/packages/install.sh --output install.sh \
  && chmod +x install.sh \
  && sed -i 's/\${sudo_cmd} service amplify-agent start > \/dev\/null 2>&1 < \/dev\/null//' install.sh \
  && yes | ./install.sh || true \
  && rm -rf /var/lib/apt/lists/*
```

... which ends up in a 193MB image. Not too much bigger than the Alpine one, but certainly has a lot more stuff in it I'd rather not be there. Also I'm really stubborn and was annoyed they took away the source repo >:(

## Usage

Provide these two env vars to the container to enable Amplify:

- `API_KEY` (from the Amplify dashboard)
- `AMPLIFY_IMAGENAME` (Used to identify this container)

There's an optional env var to disable logs from the Amplify Agent, which contain your API key:

- `NO_AGENT_LOGS=true` (Only accepts 'true')

See `nginx.conf.example` for an example nginx.conf that provides all needed logs to the Amplify agent, plus continues to output to `stdout`. This is bundled into the container by default.

## Simple usage

### Docker

```properties
docker run -p 80:80 -e API_KEY=<amplify_api_key> -e AMPLIFY_IMAGENAME=<some_identifier> makeshift27015/nginx-alpine-amplify
```

### Compose

See the `docker-compose.yml` file for a full working example. As an alternative to hardcoding the env vars into the compose file, you can simply use the variables that are already there and create a `.env` file with the following content:

```properties
API_KEY=foobarkey
AMPLIFY_IMAGENAME=foobarservername
# and optionally
NO_AGENT_LOGS=true
```

### Done

Once set up, you can then head to the [Amplify dashboard](https://amplify.nginx.com/overview/) and within a few minutes you should start seeing stats!

## Modifying Config

See `nginx.conf.example` in this repo for a full example, which is bundled by default into the container at `/etc/nginx/nginx.conf`.

This example file can be easily overwritten by extending this container:

```dockerfile
FROM makeshift27015/nginx-alpine-amplify
COPY nginx.conf /etc/nginx/nginx.conf
```

Or by mounting on top of it with Docker. See the `docker-compose.yml` file for an example.

Additionally, by default config is gathered from `/etc/nginx/conf.d/*.conf`, so you can mount additional config files there.

### TLS Support

`nginx.conf` is not instructed to tell Nginx to listen on 443 by default. If you wish to add HTTPS to your websites, the container [adferrand/dnsrobocert](https://github.com/adferrand/dnsrobocert) is really good for automatically obtaining LetsEncrypt certs, but I'm afraid it's up to you to configure Nginx to serve it ;)

### Configuring Nginx to retry a single upstream server

Nginx has an [annoying feature](https://superuser.com/questions/746028/configuring-nginx-to-retry-a-single-upstream-server) that causes it to not retry connections if you're using it as a reverse proxy and only have a single upstream server. This isn't specific to this container, it's just annoying and I want to raise awareness about it.

I have another container [Makeshift/nginx-retry-proxy](https://github.com/Makeshift/nginx-retry-proxy) that helps with that :) (shameless plug)

## Symlink & Log Shenaningans

In the Dockerfile I specifically symlink `/var/log/nginx/access-stdout.log` and `/var/log/nginx/error-stderr.log` to `/dev/stdout` and `/dev/stderr` respectively.
This means that if you use your existing Nginx config file, you **will only get output from the Nginx daemon and Amplify Agent by default** (not including lines logged to `access.log` and `error.log`). This is by design so as not to break the Amplify Agent, which relies on the default locations of Nginx logs.

To get Docker logs output, your Nginx config **must** output logs to `/var/log/nginx/access-stdout.log` and `/var/log/nginx/error-stderr.log` in addition to the default locations.
My `nginx.conf` bundled in the container does this by default.

To correctly configure your install, note specifically these lines in `nginx.conf`:

```nginx
error_log  /var/log/nginx/error.log notice;
error_log  /var/log/nginx/error-stderr.log notice;
```

and

```nginx
http {
  ...
  access_log  /var/log/nginx/access.log  main;
  access_log  /var/log/nginx/access-stdout.log main;
  ...
}
```

### Mounting logs to the host

If your sites gets a lot of traffic, your logfiles might start getting pretty big within the container. This can be solved (or at least mitigated) by mounting the default logfiles from the host filesystem. Bear in mind that the Amplify Agent still needs access to them.

#### Docker

```properties
docker run -p 80:80 -e API_KEY=<amplify_api_key> -e AMPLIFY_IMAGENAME=<some_identifier> \
-v $(pwd)/access.log:/var/log/nginx/access.log -v $(pwd)/error.log:/var/log/nginx/error.log \
makeshift27015/nginx-alpine-amplify
```

#### Compose

See the `docker-compose.yml` file for a full working example.

### Hiding your API key / Hiding the Agent logs

Set the env var `NO_AGENT_LOGS=true`.
