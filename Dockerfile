FROM nginx:alpine

COPY ./install-amplify.sh /install-amplify.sh

RUN apk add --no-cache expect build-base python3-dev && \
	wget https://raw.githubusercontent.com/nginxinc/nginx-amplify-agent/master/packages/install-source.sh && \
	chmod +x /install-amplify.sh /install-source.sh && \
	./install-amplify.sh && \
	apk del expect build-base python3-dev git gcc musl-dev linux-headers  && \
	rm -rf /nginx-amplify-agent && \
	find /usr/lib/python3.9 | grep -E "(/__pycache__$|\.pyc$|\.pyo$)" | xargs rm -rf && \
	rm -f /var/log/nginx/access.log /var/log/nginx/error.log && \
	ln -s /dev/stdout /var/log/nginx/access-stdout.log && \
	ln -s /dev/stderr /var/log/nginx/error-stderr.log

COPY entrypoint.sh /
COPY nginx.conf.example /etc/nginx/nginx.conf

EXPOSE 80

STOPSIGNAL SIGTERM

ENTRYPOINT ["/entrypoint.sh"]
