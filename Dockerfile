FROM docker:latest

RUN apk --no-cache add openssh-client docker-compose expect

COPY docker-entrypoint.sh /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]
