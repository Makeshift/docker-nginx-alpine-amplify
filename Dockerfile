# Have to use an debian/ubuntu image because we need to extract a deb file for this
FROM ubuntu as extract

RUN apt-get update && apt-get install -y curl && \
	curl -s "https://packages.amplify.nginx.com/py3/debian/pool/amplify-agent/n/nginx-amplify-agent/$(curl -s https://packages.amplify.nginx.com/py3/debian/pool/amplify-agent/n/nginx-amplify-agent/ | grep amd64 | tail -n1 | grep -Po "nginx-amplify-agent.*?.deb" | tail -n1)" --output amplify.deb && \
	dpkg-deb -R amplify.deb out

FROM nginx:alpine as build

RUN apk add --no-cache python3-dev alpine-sdk linux-headers && \
	curl -s https://bootstrap.pypa.io/get-pip.py --output get-pip.py && \
	python3 get-pip.py

RUN	python3 -m venv /opt/venv && \
	source /opt/venv/bin/activate && \
	pip3 install setproctitle greenlet gevent requests ujson netifaces pymysql setuptools

ENV PYTHONPATH=/usr/lib/python3/dist-packages

FROM nginx:alpine

RUN apk add --no-cache python3 && \
	rm -f /var/log/nginx/access.log /var/log/nginx/error.log && \
	ln -s /dev/stdout /var/log/nginx/access-stdout.log && \
	ln -s /dev/stderr /var/log/nginx/error-stderr.log

# from the deb package
ENV PYTHONPATH=/usr/lib/python3/dist-packages
COPY --from=extract /out/usr/. /usr/
COPY --from=extract /out/etc/amplify-agent/* /etc/amplify-agent/
COPY --from=build /opt/venv/lib/python3.10/site-packages/. /usr/lib/python3.10/site-packages/
COPY entrypoint.sh /
COPY nginx.conf.example /etc/nginx/nginx.conf

EXPOSE 80

STOPSIGNAL SIGTERM

ENTRYPOINT ["/entrypoint.sh"]
