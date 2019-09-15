FROM fedora:30

LABEL maintainer="Hein-Pieter van Braam-Stewart <hp@prehensile-tales.com>"

VOLUME /data
EXPOSE 389/tcp
EXPOSE 636/tcp

COPY startslapd.sh /usr/local/sbin
COPY createconfig.py /usr/local/sbin

RUN dnf -y install openldap-servers openldap-clients pwgen && \
    dnf clean all && \
    mkdir -p /data && \
    chown ldap.ldap /data && \
    chmod +x /usr/local/sbin/startslapd.sh

ENV INITIAL_SCHEMAS="core cosine inetorgperson" \
    INITIAL_SUFFIX_1=dc=example,dc=com \
    INITIAL_SUFFIX_1_ORGANIZATION="Example organization" \
    INITIAL_SUFFIX_1_USE_PPOLICY=1 \
    INITIAL_SUFFIX_1_USE_PPOLICY_HASH_CLEARTEXT=1 \
    INITIAL_SUFFIX_1_USE_PPOLICY_USE_PWCHECK=1 \
    INITIAL_SUFFIX_1_USE_MEMBEROF=1 \
    PWCHECK_MINPOINTS=3 \
    PWCHECK_MINUPPER=0 \
    PWCHECK_MINLOWER=0 \
    PWCHECK_MINDIGIT=0 \
    PWCHECK_MINPUNCT=0 \
    INITIAL_ROOTPW="" \
    SLAPD_LISTEN_LDAPS=1 \
    SLAPD_LISTEN_LDAP=1 \
    SLAPD_LISTEN_LDAPI=1 \
    SLAPD_LOGLEVEL=2

CMD /usr/local/sbin/startslapd.sh
