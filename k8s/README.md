# Efibootmgr @Scale

This container allow us to know the boot order in the cluster platforms. 
By default is in the namespace mgmt and will be deployed in all the nodes.
Uses efibootmgr in a fedora image.

## Build docker image

* Build the container image
    ```bash
    docker build -t sandstone:efibootmgr -f ./Dockerfile  ./efibootmgr
    docker tag sandstone:efibootmgr prt-registry.sova.intel.com/sandstone:efibootmgr;
    ```
* Push the container image
    ```bash
    docker push prt-registry.sova.intel.com/sandstone:efibootmgr;
    ```

## Deploy on k8s

* Crete daemonset
  ```bash
   kubectl apply -f node-manager.yaml
   ```
