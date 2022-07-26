# Firmware update @Scale

This is for Purley platforms and uses BMC redfish interface to update.
This is designed to be run on the machine that needs firmware update. Uses ipmitool to get the machine IP and performs an update.

## Build docker image

* Download Firmware
* Extract the zip file and locate the `bin` file
    Example:
    - Firmware packages can be found in: https://andante.intel.com/scripts/swview.pl?view=/Platform%20FW/Purley%20BMC%20FW%20Releases/PointRelease/Wolf%20Pass
    - The 'bin' file can be found by extracting the zip file - `Purley_2.48.2e1866be.bin` for example
* Set the env variable `FW_BIN` to point to the deb file. 
    Example:
    ```bash
    export FW_BIN=~/bin/fw/Purley_2.48.2e1866be.bin
    ```
* Set the env variable `FW_VER` with firmware version. This will be used to tag the docker image.
    Example:
    ```bash
    export FW_VER=2.48.peci.debug
    ```
* Build the container image
    ```bash
    make
    ```
* Push the container image
    ```bash
    make docker-push
    ```

## Deploy on k8s

* Make a copy fwupdate.yaml to fwupdate.out.yaml
   ```bash
    cp fwupdate.yaml fwupdate.out.yaml
    ```
* Setup desired firmware version and setup user, password.
   ```bash
   sed -i -e 's/SED_VERSION/2.48.peci.debug/' fwupdate.out.yaml
   sed -i -e 's/SED_USER/admin/' fwupdate.out.yaml
   sed -i -e 's/SED_PASSWORD/admin123/' fwupdate.out.yaml
   ```
* Make sure `node-selector` is setup correctly to pickup desired nodes.
* Crete daemonset
  ```bash
   kubectl apply -f fwupdate.out.yaml
   ```
