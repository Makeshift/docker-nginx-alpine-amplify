# Nginx + Amplify Agent in an Alpine Container

The `nginx:alpine` Docker container, + the Nginx Amplify agent. [Amplify](https://amplify.nginx.com/) is Nginx's (currently) free monitoring service for Nginx installations, which shows various stats and can alarm on downtime.

## Nginx removed the source for Nginx Amplify

In June 2022, Nginx removed the source from the https://github.com/nginxinc/nginx-amplify-agent repository for unknown reasons. As such, this container got a little bit more complicated and now has to extract the files from one of their releases, which is a bit annoying. Hopefully they'll reply to https://github.com/nginxinc/nginx-amplify-doc/issues/55 to make this simpler.

## Why does this exist

Nginx last updated their prebuilt Alpine Nginx+Amplify container (https://github.com/nginxinc/docker-nginx-amplify) in 2017 (and I literally can't even find it on Docker Hub anymore). It can no longer be built using that repo due to them removing the source from https://github.com/nginxinc/nginx-amplify-agent. They now only release full packages which are only supported by certain distros, Alpine not included. This repo and image fixes that.

This Alpine-based container is reasonably sized at ~131MB, sadly quite a lot larger than the standard `nginx:alpine` (at a slim 22MB). This is largely due to the need for Python and the packages required to get Amplify to run, and I am almost definitely not copying files optimally and would appreciate a PR with advice on it, as my Python skills are lacking.

However, it should support the following platforms:

- linux/amd64 (Confirmed working)
- linux/arm/v6
- linux/arm/v7
- linux/arm64/v8 (Confirmed working)
- linux/ppc64le
- linux/s390x

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

### Done!

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
The Dockerfile does not expose 443 by default and `nginx.conf` is not instructed to tell Nginx to listen on it. If you wish to add HTTPS to your websites, the container https://github.com/adferrand/dnsrobocert is really good for automatically obtaining LetsEncrypt certs, but I'm afraid it's up to you to configure Nginx to serve it ;)

### Configuring Nginx to retry a single upstream server
Nginx has an [annoying feature](https://superuser.com/questions/746028/configuring-nginx-to-retry-a-single-upstream-server) that causes it to not retry connections if you're using it as a reverse proxy and only have a single upstream server. This isn't specific to this container, it's just annoying and I want to raise awareness about it.

I have another container https://github.com/Makeshift/nginx-retry-proxy that helps with that :) (shameless plug)

## Symlink & Log Shenaningans

In the Dockerfile I specifically symlink `/var/log/nginx/access-stdout.log` and `/var/log/nginx/error-stderr.log` to `/dev/stdout` and `/dev/stderr` respectively.
This means that if you use your existing Nginx config file, you **will only get output from the Nginx daemon and Amplify Agent by default** (not including lines logged to `access.log` and `error.log`). This is by design so as not to break the Amplify Agent, which relies on the default locations of Nginx logs.

To get Docker logs output, your Nginx config **must** output logs to `/var/log/nginx/access-stdout.log` and `/var/log/nginx/error-stderr.log` in addition to the default locations.
My `nginx.conf` bundled in the container does this by default, and outputs a (relatively) sane format that looks like this:

```properties
172.17.0.1 - - [10/Sep/2022:13:36:32 +0000] "GET / HTTP/1.1" 200 615 "" "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/84.0.4147.105 Safari/537.36" "-" "localhost" sn="localhost" rt=0.000 ua="-" us="-" ut="-" ul="-" cs=-
```

To correctly configure your install, note specifically these lines in `nginx.conf`:

```nginx
error_log  /var/log/nginx/error.log warn;
error_log  /var/log/nginx/error-stderr.log warn;
```

and

```nginx
http {
  ...
  access_log  /var/log/nginx/access.log  main_ext;
  access_log  /var/log/nginx/access-stdout.log main_ext;
  ...
}
```

The `main_ext` is because I modify the log output. Nginx's default log name is `main`, so if you aren't using the extended logging that I add, you can simply replace `main_ext` with `main`.

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
