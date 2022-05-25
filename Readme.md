This is the source for a Docker image containing Nginx running on Alpine, plus the Amplify agent installed.

This is simplify the `nginx:alpine` image plus the Amplify agent, and a script that populates the Amplify agent config.

Provide these two env vars to the container to enable Amplify:

```
API_KEY
AMPLIFY_IMAGENAME
```

Check `docker-compose.yml` for an example of providing env vars to enable Amplify.
