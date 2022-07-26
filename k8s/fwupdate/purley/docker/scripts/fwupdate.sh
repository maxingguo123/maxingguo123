set -x
set -e

function get_lan3_ip()
{
    # xargs used to trim :https://stackoverflow.com/a/12973694
    ipmitool lan print 3 | grep "IP Address[ ]*:" | awk -F":" '{print $2}'| xargs
}

function wait_for_completion()
{

    sleep 30 # Sleep for 30 secs. Minimal time for BMC to reset
    for (( i=0; i<10; ++i)); do
        VER=`get_fw_version`
        if [[ ( -n "$VER" ) && ( "$VER" != "$OLD_VER" ) ]]; then
            break
        fi
        sleep 10
    done
}

function update_firmware()
{
    if [ -f "$FILE" ]; then
        echo "Starting firmware update"
        curl -k -u $USER:$PASSWORD https://$IP/redfish/v1/UpdateService/SoftwareInventory/BMC/Actions/Oem/Intel.Oem.UpdateBMC -XPOST -F upload="@$FILE"
    else
        echo "Cannot find firmware file"
    fi
    wait_for_completion
}

function get_fw_version()
{
    curl -k -u $USER:$PASSWORD https://$IP/redfish/v1/UpdateService/SoftwareInventory/BMC | jq -r ".Version"
}

IP=`get_lan3_ip`
FILE=firmware.bin
USER=${USER:?Required to set $USER}
PASSWORD=${PASSWORD:?Required to set $PASSWORD}

OLD_VER=`get_fw_version`
update_firmware
