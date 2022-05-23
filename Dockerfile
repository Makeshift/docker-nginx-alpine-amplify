FROM nginx:alpine

COPY ./install-amplify.sh /install-amplify.sh

RUN apk add --no-cache expect build-base python3-dev && \
		wget https://raw.githubusercontent.com/nginxinc/nginx-amplify-agent/master/packages/install-source.sh && \
		chmod +x /install-amplify.sh /install-source.sh && \
		./install-amplify.sh && \
		apk del expect build-base python3-dev git gcc musl-dev linux-headers 

COPY stub_status.conf entrypoint.sh /

EXPOSE 80

STOPSIGNAL SIGTERM

ENTRYPOINT ["/entrypoint.sh"]
