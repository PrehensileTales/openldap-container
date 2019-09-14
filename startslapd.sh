#!/bin/bash
set -e

if [ "${STARTUP_DEBUG}" -eq "1" ]; then
  set -x 
fi

if [ ! -e /data/conf.d ]; then
if [ -z "${INITIAL_ROOTPW}" ]; then
  rootpw=$(pwgen 10)
else
  rootpw="${INITIAL_ROOTPW}"
fi

  initial_suffixes=""
  suffix_variable_suffixes="$(for var in $(env | grep ^INITIAL_SUFFIX_DN | cut -d "=" -f 1); do echo ${var##*_}; done)"
  if [ ! -z "${suffix_variable_suffixes}" ]; then
    for suffix_variable_suffix in ${suffix_variable_suffixes}; do
      org="INITIAL_ORGANIZATION_${suffix_variable_suffix}"
      suffix="INITIAL_SUFFIX_DN_${suffix_variable_suffix}" 
      if [ -z "${!org}" ]; then
        echo "ERROR: Suffix ${!suffix} has no organization name set"
        exit 1
      fi
      initial_suffixes="${initial_suffixes} ${!suffix}"
    done
  fi

  mkdir -p /data/conf.d
  mkdir -p /data/databases

/usr/sbin/slapadd -F /data/conf.d -n0 <<EOF
dn: cn=config
objectClass: olcGlobal
cn: config

dn: cn=module,cn=config
objectClass: olcModuleList
cn: module
olcModulepath: /usr/lib64/openldap

dn: cn=schema,cn=config
objectClass: olcSchemaConfig
cn: schema

$(for schema in ${INITIAL_SCHEMAS}; do echo include: file:///etc/openldap/schema/${schema}.ldif; done)

dn: olcDatabase=config,cn=config
objectClass: olcDatabaseConfig
olcDatabase: config
olcAccess: to * by dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth" manage by * none
olcRootDN: cn=manager,cn=config
olcRootPW: $(/usr/sbin/slappasswd -s "${rootpw}")

dn: olcDatabase=monitor,cn=config
objectClass: olcDatabaseConfig
olcDatabase: monitor
olcAccess: to * by dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth" read by * none

$(for suffix in ${initial_suffixes}; do 
  mkdir -p "/data/databases/${suffix}"
  echo "dn: olcDatabase=mdb,cn=config
objectClass: olcDatabaseConfig
objectClass: olcMdbConfig
olcDatabase: mdb
olcSuffix: ${suffix}
olcRootDN: cn=Manager,${suffix}
olcDbDirectory:	/data/databases/${suffix}
olcDbIndex: objectClass eq,pres
olcDbIndex: ou,cn,mail,surname,givenname eq,pres,sub
olcAccess: {0}to attrs=userPassword by self write by anonymous auth by dn.base=gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth write by * none
olcAccess: {1}to * by dn.base=gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth write by * read
"; done)
EOF

  for suffix_variable_suffix in ${suffix_variable_suffixes}; do
    org="INITIAL_ORGANIZATION_${suffix_variable_suffix}"
    suffix="INITIAL_SUFFIX_DN_${suffix_variable_suffix}"
    /usr/sbin/slapadd -F /data/conf.d -b ${!suffix} <<EOF
dn: ${!suffix}
objectClass: dcObject
objectClass: organization
dc: $(echo ${!suffix} | sed -e 's/dc=\([^,]\+\).*/\1/')
o: ${!org}
EOF
  done

  chown -R ldap.ldap /data/

  echo "NOTE: cn=manager,cn=config password is ${rootpw}"
  echo "NOTE: this message will not be repeated!"
fi

unset INITIAL_ROOTPW
unset rootpw

urls=""
if [ ${SLAPD_LISTEN_LDAP} -eq 1 ]; then urls="$urls ldap://"; fi
if [ ${SLAPD_LISTEN_LDAPS} -eq 1 ]; then urls="$urls ldaps://"; fi
if [ ${SLAPD_LISTEN_LDAPI} -eq 1 ]; then urls="$urls ldapi://%2Fdata%2Fldapi/"; fi

/usr/sbin/slapd -h "${urls}" -u ldap -d${SLAPD_LOGLEVEL} -F /data/conf.d
