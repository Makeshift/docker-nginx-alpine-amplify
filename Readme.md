This is the source for a Docker image containing Nginx running on Alpine, plus the Amplify agent installed.

This is simply the `nginx:alpine` image plus the Amplify agent, and a script that populates the Amplify agent config. I noticed that Nginx didn't really provide that as a prebuilt image, so here it is. If it needs updating, please open an issue.

Provide these two env vars to the container to enable Amplify:

```
API_KEY (from the Amplify dashboard)
AMPLIFY_IMAGENAME (Used to identify this container)
```

See `nginx.conf.example` for an example nginx.conf that provides all needed logs to the Amplify agent, plus continues to output to `stdout`.

Check `docker-compose.yml` for a full working example.

# Simple usage

```
docker run -p 80:80 -e API_KEY=<amplify_api_key> -e AMPLIFY_IMAGENAME=<some_identifier> makeshift27015/nginx-alpine-amplify
```

then head to the [Amplify dashboard](https://amplify.nginx.com/overview/).
