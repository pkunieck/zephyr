# sdk-docker-intel
Zephyr project sdk-docker adapted for Intel-internal use on OneRTOS & related projects.

## Changes from project docker

* Github actions build/deploy workflow (see .github/workflows in this repo)
* Inject proxy variables during build
* Modified apt-key download process to function with Intel SSL proxies
* Commented-out installs for Zephyr SDK + ARM compiler - we host these via NFS to reduce network load  
* Configured docker build to pickup the build-user UID/GID to automatically synchronize non-root container user
* Inject ssh host-key for gitlab.devtools.intel.com to allow ssh git clones from container context


## Notes

Current 1RTOS DevOps infrastructure requires containers to all run as jenkins user/group.


See README.md for additional info + usage instructions

