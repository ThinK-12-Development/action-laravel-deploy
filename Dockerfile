FROM alpine
RUN apk update && apk add bash openssh
COPY . /
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]