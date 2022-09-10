FROM nginx:alpine as build

RUN apk add --no-cache python3-dev alpine-sdk linux-headers curl dpkg grep && \
	curl -s https://bootstrap.pypa.io/get-pip.py --output get-pip.py && \
	python3 get-pip.py

RUN	python3 -m venv /opt/venv && \
	source /opt/venv/bin/activate && \
	pip3 install setproctitle greenlet gevent requests ujson netifaces pymysql psutil

# Grabs and extracts the latest python version of the amplify agent, approximately
RUN curl -s "https://packages.amplify.nginx.com/py3/debian/pool/amplify-agent/n/nginx-amplify-agent/$(curl -s https://packages.amplify.nginx.com/py3/debian/pool/amplify-agent/n/nginx-amplify-agent/ | grep amd64 | tail -n1 | grep -Po "nginx-amplify-agent.*?.deb" | tail -n1)" --output amplify.deb && \
	dpkg-deb -R amplify.deb out

FROM nginx:alpine

RUN apk add --no-cache python3 util-linux && \
	rm -f /var/log/nginx/access.log /var/log/nginx/error.log && \
	ln -s /dev/stdout /var/log/nginx/access-stdout.log && \
	ln -s /dev/stderr /var/log/nginx/error-stderr.log && \
	mkdir /var/log/amplify-agent

# from the deb package
ENV PYTHONPATH=/usr/lib/python3.10/site-packages/:/usr/lib/python3/dist-packages

COPY --from=build /out/usr/. /usr/
COPY --from=build /out/etc/amplify-agent/* /etc/amplify-agent/
COPY --from=build /opt/venv/lib/python3.10/site-packages/. /usr/lib/python3.10/site-packages/
COPY entrypoint.sh /
COPY nginx.conf.example /etc/nginx/nginx.conf

# the psutil bundled with the agent seems to be broken, so we remove it and use the one from the venv
RUN rm -rf /usr/lib/python3/dist-packages/amplify/psutil

EXPOSE 80

STOPSIGNAL SIGTERM

ENTRYPOINT ["/entrypoint.sh"]
