FROM fedora:30

LABEL maintainer="Hein-Pieter van Braam-Stewart <hp@prehensile-tales.com>"

VOLUME /data
EXPOSE 389/tcp
EXPOSE 636/tcp

RUN dnf -y install openldap-servers openldap-clients pwgen && \
    dnf clean all && \
    mkdir -p /data && \
    chown ldap.ldap /data

COPY startslapd.sh /usr/local/sbin
RUN chmod +x /usr/local/sbin/startslapd.sh

ENV INITIAL_SCHEMAS core cosine inetorgperson
ENV INITIAL_SUFFIX_DN_1 dc=example,dc=com
ENV INITIAL_ORGANIZATION_1 Example organization
ENV INITIAL_ROOTPW ""

ENV SLAPD_LISTEN_LDAPS=1
ENV SLAPD_LISTEN_LDAP=1
ENV SLAPD_LISTEN_LDAPI=1
ENV SLAPD_LOGLEVEL=2

ENV STARTUP_DEBUG=0

CMD /usr/local/sbin/startslapd.sh
