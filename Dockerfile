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
COPY createconfig.py /usr/local/sbin
RUN chmod +x /usr/local/sbin/startslapd.sh

ENV INITIAL_SCHEMAS core cosine inetorgperson
ENV INITIAL_SUFFIX_1 dc=example,dc=com
ENV INITIAL_SUFFIX_1_ORGANIZATION Example organization
ENV INITIAL_SUFFIX_1_USE_PPOLICY 1
ENV INITIAL_SUFFIX_1_USE_PPOLICY_HASH_CLEARTEXT 1
ENV INITIAL_SUFFIX_1_USE_PPOLICY_USE_PWCHECK 1
ENV INITIAL_SUFFIX_1_USE_MEMBEROF 1

ENV PWCHECK_MINPOINTS 3
ENV PWCHECK_MINUPPER 0
ENV PWCHECK_MINLOWER 0
ENV PWCHECK_MINDIGIT 0
ENV PWCHECK_MINPUNCT 0

ENV INITIAL_ROOTPW ""

ENV SLAPD_LISTEN_LDAPS 1
ENV SLAPD_LISTEN_LDAP 1
ENV SLAPD_LISTEN_LDAPI 1
ENV SLAPD_LOGLEVEL 2

CMD /usr/local/sbin/startslapd.sh
