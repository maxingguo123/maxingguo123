# Using XmlCli in the cluster

## XmlCli Basics
XmlCli is an Intel internal tool that can be used to read and modify the BIOS knob configuration of Intel reference
platforms. BIOSes that support XmlCli expose their configuration as an xml file that can be downloaded by XmlCli. Then,
XmlCli can post requests to the BIOS via a mailbox using information from the xml file to change the configuration. For
more information, check the readme files in the pysvtools.xmlcli package.

BIOS knob configurations are specified to XmlCli with a common format. Any XmlCli command will trigger XmlCli to
to download the xml file and save it as `PlatformConfig.xml`. You can build a BIOS knob spec by assembling a comma
delimited list in the format `KnobName=value,KnobName2=value,KnobName3=value`, and so on. You can also use ini files for
this, see the "Monitoring BIOS knob configuration" section for more information on ini files. Numeric values should be specified in hex with the "0x" prefix. XmlCli has some inconsistencies in how it treats the input and how it prints output (base 10 in, base 16 without 0x out, for example). So, if you provide the input in hex with 0x, the wrapper script will be able to apply the correct validation. 
You may see false not ok messages if you don't.

To view the `PlatformConfig.xml` file to get the knob names and valid choices, run the following:
```bash
<host> $ docker run --privileged --entrypoint bash -e XC_BYPASS_HANG=true -it prt-registry.sova.intel.com/sandstone:xmlcli
<container> # python3 XmlCliCmd.py savexml
```
Then, you can view the file in the container at `/xmlcli/pysvtools/xmlcli/out/PlatformConfig.xml`. Starting the
container this way also allows you to manually run XmlCli commands (shortcut with `XmlCliCmd.py` or by importing 
`pysvtools.xmlcli`). Run `python3 XmlCliCmd.py --help` for options.

To automatically save the xml file to the current directory on the host, you can run this sequence of commands:
```bash
docker run --privileged -d --rm -e XC_OP=savexml --name xmlcli-savexml -it prt-registry.sova.intel.com/sandstone:xmlcli
sleep 10  # Only needed if running in script or pasting all commands - xml file takes some time to save, if running one
          # command at a time, just wait a bit for the XML file to save.
docker cp xmlcli-savexml:/xmlcli/pysvtools/xmlcli/out/PlatformConfig.xml .
docker kill xmlcli-savexml
```

Note: Running XmlCli requires the `/dev/mem` device to be available for raw memory access from Linux. Some distributions
disable this by default (for example, Clear Linux). If `/dev/mem` is not available, the kernel must be rebuilt with this
support enabled. The production clusters have `/dev/mem` enabled in the Ironic images to provide this functionality.

## Reading BIOS knobs
BIOS knobs can be read and compared using the `readknobs` CLI command. To trigger this with docker, use the following example:
```bash
docker run --privileged -e XC_OP=readknobs -e XC_KNOB=<list_of_knobs> -e XC_BYPASS_HANG=true -it prt-registry.sova.intel.com/sandstone:xmlcli
```
This will return the XmlCli output with the exact knob settings. You can inspect the output of XmlCli or the summary
dictionary printed by the wrapper script to get the settings. However, for most use cases, this is not necessary as
the wrapper script enforces that the returned knobs match the provided string.
 
If the knob configuration matches the provided string, it will print out `ok 1 - xmlcli`, otherwise (including errors 
preventing XmlCli from working), `not ok 1 - xmlcli` will be printed. 

The return code will also be set accordingly. Ensure `XC_BYPASS_HANG` exists in the container (any value),
otherwise the container will hang. This is to support execution with k8s.

k8s execution can be done with the `xmlcli.yaml` file in this folder, which specifies a daemonset that will run XmlCli
on all machines that are in the selected namespace with the selected label.
```bash
sed \
    -e "s/NAMESPACE/mgmt/" \
    -e "s/XC_CMD_OP/readknobs/" \
    -e "s/XC_CMD_KNOB/<list_of_knobs>/" \
    -e "s/SANDSTONE_NODE_LABEL/<label_to_run_on>/" \
    -e "s/SANDSTONE_NAME/xmlcli/" \
    -e "s/DOCKER_TAG/xmlcli/" \
    -e "s/REGISTRY/prt-registry.sova.intel.com/" \
    -e "s/REPO/sandstone/" xmlcli.yaml | kubectl ${KUBECTL_ARGS} ${KUBECTL_XMLCLI_XTRA_ARGS} apply -f -
```
The pods that pass verification will be marked as `ready` in k8s, the ones that don't will not. If telemetry gathering
is set up on the cluster, the full logs will be available there, or can be dumped from specific pods with `kubectl logs`.

Once the container has run, it can be deleted by rerunning the `sed` command but changing the `kubectl` command it is
piped to from `apply` to `delete`, or by directly deleting the daemonset with `kubectl delete`. 

## Programming BIOS knobs
Programming works the same way as reading, all that has to change is `XC_OP`. If `XC_OP` is `progknobs`, the container
will program the knob string instead of checking the SUT configuration with it.
```bash
docker run --privileged -e XC_OP=progknobs -e XC_KNOB=<list_of_knobs> -e XC_BYPASS_HANG=true -it prt-registry.sova.intel.com/sandstone:xmlcli
```
Note that the SUT will need a cold reset (regular reboot is not enough) to apply the change.

With k8s, you can use the `xmlcli_pipeline.sh` script to automatically program the knobs, reboot the cluster, and
check the configuration after the reboot.
```bash
XC_KNOB=<knob_string_to_program> ./xmlcli_pipeline.sh
```
You can control the namespace targeted with the `XC_NAMESPACE` (xmlcli container) and `NS` (reboot container) vars.
The `XC_LABEL` var will control the label targeted for knob programming (both xmlcli and reboot containers).

## Monitoring BIOS knob configuration
A persistent XmlCli container can be deployed using the `xmlcli_monitor.yaml` file. This will run a daemonset that will
periodically check knobs specified by an ini file and log the results to stdout (and, thus, Elasticsearch).

The yaml file has a few options to select.
- NAMESPACE: Desired namespace to run the monitor container in
- XC_MONITOR_INTERVAL: Time in seconds in between each configuration check
- SANDSTONE_NODE_LABEL: The monitor container will only run on nodes with the selected label
- SANDSTONE_NAME: Daemonset name to use. `xmlcli-monitor` or similar.
- DOCKER_TAG: Tag of the XmlCli container to use. `xmlcli` will point to the latest rev.
- REGISTRY: Docker registry to pull `DOCKER_TAG` from. Default should be `prt-registry.sova.intel.com`
- REPO: Docker repo to pull `DOCKER_TAG` from. Default should be `sandstone`.

Example deployment:
```bash
sed \
    -e "s/NAMESPACE/mgmt/" \
    -e "s/XC_MONITOR_INTERVAL/30/" \
    -e "s/SANDSTONE_NODE_LABEL/xmlcli/" \
    -e "s/SANDSTONE_NAME/xmlcli-monitor/" \
    -e "s/DOCKER_TAG/xmlcli/" \
    -e "s/REGISTRY/prt-registry.sova.intel.com/" \
    -e "s/REPO/sandstone/" xmlcli_monitor.yaml | kubectl apply -f -
```

Once deployed, the container will remain in the `ContainerCreating` state until a config file is applied. The pod will 
be looking for a configmap named `knob-monitor-config-map`, which must include a `BiosKnobs.ini` file, which XmlCli will
consume. See `bios_knob_profiles` for examples to see how this is done. These files can be edited and applied to change
the expected configuration.

The only option to select in the example yaml is the namespace to deploy the configmap to.

Example deployment:
```bash
sed -e "s/NAMESPACE/mgmt/" bios_knob_profiles/spinlock_cfgmap.yaml | kubectl apply -f -
```

BIOS knob specifications should match the XmlCli knob string format, but with one knob per line. The given value is the
"expected" value. If the given value doesn't match what is on the platform for any knob, the container will report the
system as out of spec.
```ini
[BiosKnobs]
XmlCliShortKnobName1=<value1>
XmlCliShortKnobName2=<value2>
XmlCliShortKnobName3=<value3>
```
The newline characters in the file should be replaced with the string literal `\n` when creating the config map.

## XmlCli debug tips
- If you are getting similar but not identical knob name in the readback compared to the string, check the knob offset
in the `PlatformConfig.xml` file. Some knobs are aliased and refer to the same actual knob. If this happens, use the same
name that XmlCli returns to avoid mismatch.
- If you are getting a completely different knob in the readback, this usually indicates a BIOS issue (BIOS not updating
the offsets correctly). If this happens, try a different BIOS version and file an issue with the BIOS team.
- For XmlCli support, contact Amol Shinde (amol.shinde@intel.com).

# Building the XmlCli container
XmlCli is maintained in the Intel PyPI repo. This repo contains PythonSV collateral. XmlCli does not rely on PythonSV,
but has traditionally been distributed with it. As such, access to the PyPI repo requires PythonSV access. The build 
flow is automated, but pip will ask for credentials if a pip keyring is not set up. 

For access to the PyPI repo, follow the instructions at the [PythonSV website](https://pythonsv.app.intel.com/requestaccess).

Once you have access to the PyPI repo, you can build the XmlCli container by running the following command from this folder.
```bash
DOCKER_TAG=<desired_docker_tag> make docker
```
This will automatically download the latest XmlCli release, extract it, and build + push the container.
