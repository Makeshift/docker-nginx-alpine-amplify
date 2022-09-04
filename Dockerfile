FROM nginx:alpine

COPY install-amplify.expect install-source.sh /

# TODO It would be slightly more space/time-efficient to multi-stage this rather than installing
#  all the build tools and then removing them.
RUN apk add --no-cache expect build-base python3-dev && \
	chmod +x /install-amplify.expect /install-source.sh && \
	./install-amplify.expect && \
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
