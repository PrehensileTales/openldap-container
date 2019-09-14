## Simple OpenLDAP container.

This container installs a simple non-replicated OpenLDAP server. All data is stored on the `/data/` volume.

## Running
The container is build by Quay.io at `quay.io/tmm/openldap`.

The following environment variables affect the runtime behavior of the container:

* `SLAPD_LISTEN_LDAPS` Listen to LDAPS (port 636) defaults to `1`
* `SLAPD_LISTEN_LDAP` Listen to LDAP (port 389) defaults to `1`
* `SLAPD_LISTEN_LDAPI` Listen to LDAPI (/data/ldapi) defaults to `1`
* `SLAPD_LOGLEVEL` Set the SLAPD loglevel. Defaults to `2`
* `STARTUP_DEBUG` Enable debugging of the startup script. Defaults to `0`

## Configuration
The following environment variables affect the initial configuration:

`INITIAL_SCHEMAS`
Set the initial schemas to be loaded into the directory. These are the schemas shipped by OpenLDAP. The following schemas are shipped with this container:
* collective
* corba
* core
* cosine
* duaconf
* dyngroup
* inetorgperson
* java
* misc
* nis
* openldap
* pmi
* ppolicy

By default the container loads `core cosine inetorgperson`

`INITIAL_SUFFIX_DN_`<string>
`INITIAL_ORGANIZATION_`<string>

Allows the creation of initial suffixes when the container is first started. By default:
```
INITIAL_SUFFIX_DN_1=dc=example,dc=com
INITIAL_ORGANIZATION_1=Example organization
```
It is possible to add more default suffixes by adding `_2` `_3` etc

`INITIAL_ROOTPW`
The initial root password for cn=config. The name for the root account is cn=manager,cn=config. If this is not set a random password will be generated and will be printed the first time the container starts up. This will not be repeated on subsequent starts.


