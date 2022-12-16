# sdk-docker-intel
Zephyr project sdk-docker adapted for Intel-internal use on OneRTOS & related projects.

## Github Actions CD

**This repo has embedded Github Continous Delivery workflow that automatically builds & deploys the sdk-docker-intel:main container image. The following steps will occur on any push to the 'main-intel' branch:**

1. A new sdk-docker-intel:main.stg container image will be built and pushed to the zephyr-ci local registry
3. Using production runners, a CI twister run on a known-good tag ('1rtos-ci-self-test')
4. If the twister execution passes, the docker image is retagged main & pushed to local registry.

### Release process:

1. Update [tag 1rtos-ci-self-test](https://github.com/intel-innersource/os.rtos.zephyr.zephyr/releases/tag/1rtos-ci-self-test) to point to the latest passing commit on os.zephyr.zephyr main-intel.
2. Merge external Zephyr project sdk-docker changes into branch main-intel
3. CD workflow will run & test new container image against 1rtos-ci-self-test tag & promote new image to production automatically if passing
4. If test fails, a DevOps engineer will need to resolve the update/deployment manually. 

## Changes from project docker

**Some changes were required for the external Zephyr sdk-docker to function inside Intel:**

* Github actions build/deploy workflow (see .github/workflows in this repo)
* Inject proxy variables during build
* Modified apt-key download process to function with Intel SSL proxies
* Commented-out installs for Zephyr SDK + ARM compiler - we host these via NFS to reduce network load  
* Configured docker build to pickup the build-user UID/GID to automatically synchronize non-root container user
* Inject ssh host-key for gitlab.devtools.intel.com to allow ssh git clones from container context

## Notes

Current 1RTOS DevOps infrastructure requires containers to all run as jenkins user/group.

See README.md for additional info + usage instructions

