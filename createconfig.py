#!/usr/bin/python3

import os
import re
import shutil
from subprocess import run, PIPE

suffixes = {}
use_ppolicy = False
use_memberof = False

re = re.compile('INITIAL_SUFFIX_([0-9]+)_?(.*)')
for key in os.environ.keys():
  match = re.match(key)

  if match:
    i = match[1]
    if not i in suffixes: suffixes[i] = {}

    if not match[2]:
      suffixes[i]['dn'] = os.environ[key]
    else:
      suffixes[i][match[2]] = os.environ[key]

for idx, suffix in suffixes.items():
  if not 'ORGANIZATION' in suffix:
    print(f"Error: Suffix {suffix['dn']} does not have an organization")
    exit(1)

  if 'USE_PPOLICY' in suffix:
    if suffix['USE_PPOLICY'] == "1": use_ppolicy = True
  if 'USE_MEMBEROF' in suffix:
    if suffix['USE_MEMBEROF'] == "1": use_memberof = True

rootpw = ""
if 'INITIAL_ROOTPW' in os.environ:
  if len(os.environ['INITIAL_ROOTPW']) > 0:
    rootpw = os.environ['INITIAL_ROOTPW']
    del os.environ['INITIAL_ROOTPW']

if not rootpw:
  rootpw = run(['pwgen', '10'], stdout=PIPE).stdout.decode().strip()

rootpw_encoded = run(['slappasswd', '-s', rootpw], stdout=PIPE).stdout.decode().strip()

config_ldif="""
dn: cn=config
objectClass: olcGlobal
cn: config

dn: cn=module,cn=config
objectClass: olcModuleList
cn: module
olcModulepath: /usr/lib64/openldap
"""
if use_ppolicy:
  config_ldif += "olcModuleLoad: ppolicy\n"
if use_memberof:
  config_ldif += "olcModuleLoad: memberof\n"

config_ldif += """

dn: cn=schema,cn=config
objectClass: olcSchemaConfig
cn: schema

"""

if 'INITIAL_SCHEMAS' in os.environ:
  for schema in os.environ['INITIAL_SCHEMAS'].split(" "):
     config_ldif += f"include: file:///etc/openldap/schema/{schema}.ldif\n"
  if not 'ppolicy' in os.environ['INITIAL_SCHEMAS'].split(" ") and use_ppolicy:
     config_ldif += f"include: file:///etc/openldap/schema/ppolicy.ldif\n"

config_ldif += f"""
dn: olcDatabase=config,cn=config
objectClass: olcDatabaseConfig
olcDatabase: config
olcAccess: to * by dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth" manage by * none
olcRootDN: cn=manager,cn=config
olcRootPW: {rootpw_encoded}

dn: olcDatabase=monitor,cn=config
objectClass: olcDatabaseConfig
olcDatabase: monitor
olcAccess: to * by dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth" read by * none
"""

db_num = 2
for idx, suffix in suffixes.items():
  os.mkdir(f"/data/databases/{suffix['dn']}")

  overlay_num = 0
  config_ldif += f"""
dn: olcDatabase=mdb,cn=config
objectClass: olcDatabaseConfig
objectClass: olcMdbConfig
olcDatabase: mdb
olcSuffix: {suffix['dn']}
olcRootDN: cn=Manager,{suffix['dn']}
olcDbDirectory: /data/databases/{suffix['dn']}
olcDbIndex: objectClass eq,pres
olcDbIndex: ou,cn,mail,surname,givenname eq,pres,sub
olcAccess: {{0}}to attrs=userPassword by self =wx by anonymous auth by dn.base=gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth write by * none
olcAccess: {{1}}to * by dn.base=gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth write by * read
"""

  if 'USE_PPOLICY' in suffix and suffix['USE_PPOLICY'] == '1':
    config_ldif += f"""
dn: olcOverlay={ {overlay_num} }ppolicy,olcDatabase={ {db_num} }mdb,cn=config
objectClass: olcConfig
objectClass: olcOverlayConfig
objectClass: olcPPolicyConfig
objectClass: top
olcOverlay: { {overlay_num} }ppolicy
olcPPolicyDefault: cn=default,ou=policies,{suffix['dn']}
"""
    if 'USE_PPOLICY_HASH_CLEARTEXT' in suffix and suffix['USE_PPOLICY_HASH_CLEARTEXT'] == '1':
       config_ldif += "olcPPolicyHashCleartext: TRUE\n"

    overlay_num += 1

  if 'USE_MEMBEROF' in suffix and suffix['USE_MEMBEROF'] == '1':
    config_ldif += f"""
dn: olcOverlay={ {overlay_num} }memberof,olcDatabase={ {db_num} }mdb,cn=config
objectClass: olcConfig
objectClass: olcMemberOf
objectClass: olcOverlayConfig
objectClass: top
olcOverlay: { {overlay_num} }memberof
olcMemberOfDangling: drop
olcMemberOfGroupOC: groupOfNames
olcMemberOfMemberAD: member
olcMemberOfMemberOfAD: memberOf
olcMemberOfRefInt: TRUE
"""
    overlay_num += 1

  db_num += 1

print("Loading cn=config ldif")
print(config_ldif)
out = run(['/usr/sbin/slapadd', '-F', '/data/conf.d', '-n0'], stdout=PIPE, input=config_ldif, encoding='ascii')
print(out.stdout)
if out.returncode:
  print("Error:") 
  print(out.stderr)
  exit(1)
else:
  print("Success!")

for idx, suffix in suffixes.items():
  suffix_ldif=f"""
dn: {suffix['dn']}
objectClass: dcObject
objectClass: organization
dc: {suffix['dn'].split("=")[1].split(",")[0]}
o: {suffix['ORGANIZATION']}
"""
  if 'USE_PPOLICY' in suffix and suffix['USE_PPOLICY'] == '1':
    suffix_ldif += f"""
dn: ou=policies,{suffix['dn']}
objectClass: organizationalUnit
objectClass: top
ou: policies

dn: cn=default,ou=policies,{suffix['dn']}
objectClass: person
objectClass: pwdPolicy
objectClass: top
cn: default
pwdAttribute: userPassword
sn: dummy value
pwdAllowUserChange: TRUE
pwdCheckQuality: 2
pwdExpireWarning: 600
pwdFailureCountInterval: 30
pwdGraceAuthNLimit: 5
pwdInHistory: 5
pwdLockout: TRUE
pwdLockoutDuration: 0
pwdMaxAge: 0
pwdMaxFailure: 5
pwdMinAge: 0
pwdMinLength: 8
pwdMustChange: FALSE
pwdSafeModify: FALSE
"""
  if 'USE_PPOLICY_USE_PWCHECK' in suffix and suffix['USE_PPOLICY_USE_PWCHECK'] == '1':
    suffix_ldif += "objectClass: pwdPolicyChecker\n"
    suffix_ldif += "pwdCheckModule: check_password.so\n"

  print(f"Loading {suffix['dn']} ldif")
  print(suffix_ldif)
  out = run(['/usr/sbin/slapadd', '-F', '/data/conf.d', '-b', suffix['dn']], stdout=PIPE, input=suffix_ldif, encoding='ascii')
  print(out.stdout)
  if out.returncode:
    print("Error:") 
    print(out.stderr)
    exit(1)

print(f"Note: cn=manager,cn=config password is {rootpw}")
print("Note: this note will not be repeated!")
