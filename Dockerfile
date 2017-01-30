FROM appropriate/curl

MAINTAINER Luis David Barrios Alfonso (luisdavid.barrios@agsnasoft.com / cyberluisda@gmail.com)

ADD files/es-ctl.sh /bin
RUN chmod a+x /bin/es-ctl.sh

RUN mkdir -p /etc/es-ctl

VOLUME /etc/es-ctl

ENTRYPOINT ["/bin/es-ctl.sh"]
CMD ["--help"]
