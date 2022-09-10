# I know it's generally cleaner/best practice to use a less-polluted image as the build image, but I'm using the same image for both build and runtime for simplicity
FROM nginx:alpine as build

# Some arch's require libffi-dev to build some of the python deps since there are no prebuilt wheels
RUN apk add --no-cache python3-dev alpine-sdk linux-headers curl dpkg grep libffi-dev \
	&& curl -s https://bootstrap.pypa.io/get-pip.py --output get-pip.py \
	&& python3 get-pip.py

# The approximate list of requirements can be grabbed from https://packages.amplify.nginx.com/py3/debian/dists/buster/amplify-agent/binary-amd64/Packages
# Though it required some tweaking to get it to work
RUN	python3 -m venv /opt/venv \
	# Activate the venv so things actually install in there
	&& source /opt/venv/bin/activate \
	# I think installing wheel first allows it to skip a lot of the legacy build stuff, but my Python isn't very good so please correct me if wrong
	&& pip3 install wheel \
	&& pip3 install setproctitle greenlet gevent requests ujson netifaces pymysql psutil \
	# This weirdness is explained below above the ENV
	&& mv /opt/venv/lib/python3* /opt/venv/lib/python3-custom

# Grabs and extracts the latest python version of the amplify agent, approximately. Yeah it's icky, but I'm keeping it as one line to annoy people.
RUN curl -s "https://packages.amplify.nginx.com/py3/debian/pool/amplify-agent/n/nginx-amplify-agent/$(curl -s https://packages.amplify.nginx.com/py3/debian/pool/amplify-agent/n/nginx-amplify-agent/ | grep amd64 | tail -n1 | grep -Po "nginx-amplify-agent.*?.deb" | tail -n1)" --output amplify.deb \
	&& dpkg-deb -R amplify.deb out

FROM nginx:alpine

# util-linux is required for the agent to get CPU info
RUN apk add --no-cache python3 util-linux

# The symlinks are just nice to have to get output to docker logs from Nginx
# We use /proc/1/fd/1 rather than /dev/{stdout,stderr} because these processes fork, and Docker logs only come from PID 1
#  So we need to force everything to print to PID 1's output stream
# If we only used /dev/{stdout,sterr} they would print to their own PID's stdout/sterr, which is useless for Docker logging
RUN mkdir /var/log/amplify-agent \
	&& ln -sf /proc/1/fd/1 /var/log/amplify-agent/agent.log \
	&& ln -sf /proc/1/fd/1 /var/log/nginx/access-stdout.log \
	&& ln -sf /proc/1/fd/1 /var/log/nginx/error-stderr.log \
	&& chown -R 101:101 /var/log/amplify-agent/ /var/log/nginx/


# The deb package uses python3 as its site-packages dir, so rather than dealing with them maybe breaking stuff in the future, we just
#  add it as a source on the _end_ of the pythonpath (so it uses the more up-to-date installed packages from the venv by default)
# As of the time of writing, the Alpine amd64 repos have Python 3.10 and the arm64 repos have Python 3.9 (making different folder structures)
#  So, I'm trying to be a bit more version agnostic (rather than pinning to 3.9) by sticking my packages into a custom site-packages dir 
#  rather than overwriting stuff that the system Python (or the Amplify Agent) manages.
# I tried some shenanigans with combining the two directories but it ended up at an identical image size, and this is cleaner anyway.
ENV PYTHONPATH=/usr/lib/python3-custom/site-packages/:/usr/lib/python3/dist-packages

# The '.' will merge, apparently. I'm not sure if it's a bug or a feature, but it works.
COPY --from=build /out/usr/. /usr/
COPY --from=build /out/etc/amplify-agent/* /etc/amplify-agent/
COPY --from=build /opt/venv/lib/python3-custom/site-packages/. /usr/lib/python3-custom/site-packages/
COPY entrypoint.sh /
COPY nginx.conf.example /etc/nginx/nginx.conf

# The psutil bundled with the agent doesn't seem to work on alpine, so we remove it entirely and force it to use the one from the venv
#  (It was choosing to use the one from the deb package unless I deleted it, not sure why)
RUN rm -rf /usr/lib/python3/dist-packages/amplify/psutil

EXPOSE 80
EXPOSE 443

STOPSIGNAL SIGTERM

ENTRYPOINT ["/entrypoint.sh"]
