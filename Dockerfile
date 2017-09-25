FROM appropriate/curl

MAINTAINER Luis David Barrios Alfonso (luisdavid.barrios@agsnasoft.com / cyberluisda@gmail.com)

#Add dockerize tool
ENV DOCKERIZE_VERSION v0.5.0
RUN curl -L https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    | tar -C /usr/local/bin -xzvf -

# Add jq and other software base
RUN apk --update add jq \
  && rm -fr /var/cache/apk/*

ADD files/es-ctl.sh /bin
RUN chmod a+x /bin/es-ctl.sh

RUN mkdir -p /etc/es-ctl

VOLUME /etc/es-ctl

ENTRYPOINT ["/bin/es-ctl.sh"]
CMD ["--help"]
