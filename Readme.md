This is the source for a Docker image containing Nginx running on Alpine, plus the Amplify agent installed.

This is simply the `nginx:alpine` image plus the Amplify agent, and a script that populates the Amplify agent config. I noticed that Nginx didn't really provide that as a prebuilt image, so here it is. If it needs updating, please open an issue.

Provide these two env vars to the container to enable Amplify:

```
API_KEY
AMPLIFY_IMAGENAME
```

Check `docker-compose.yml` for an example of providing env vars to enable Amplify.
