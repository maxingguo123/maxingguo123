#!/usr/bin/env python3

import glob
import os
import shutil
import subprocess
import sys

import yaml

CONFIG_FILE = '/ucode_config/ucode_config.yaml'


def ucode():
    ucode_dir = "ucode"
    cluster_config = yaml.safe_load(open(CONFIG_FILE))
    try:
        endpoint = "{}/api/instant_query?key=name&value={}&location={}".format(
                cluster_config['cluster_endpoint'], os.getenv("NODENAME"),
                cluster_config['location'])
        print(endpoint)
        node_pool = yaml.safe_load(subprocess.check_output(
            ['curl', '-s', endpoint]))[0]['pool']
    except Exception:
        print("Microcode : Could not talk to server {}"
              .format(str(cluster_config['cluster_endpoint'])))
        node_pool = None
        # if we cannot comunicate with the server the best decision
        # is to skip the loader for ucode
        ucode_dir = "Skip"
    if cluster_config.get('pools', False) and \
       cluster_config['pools'].get(node_pool, False):
        ucode_dir = cluster_config['pools'][node_pool]
    # SKIPPING DBG POOL NAMES
    if ucode_dir in ["skip", "Skip", "SKIP"] or ("DBG" in node_pool and ucode_dir == "ucode"):
        print("Microcode: Pool desginated for skipping ucode loading")
        print("Microcode Ver: {}".format(subprocess.check_output(
            ['rdmsr', '0x8b'])))
        pwd = os.getcwd()
        print("Init-Container Revision: {}".format(subprocess.check_output(
            ['cat', pwd+'/init-cont-ver.txt'])))
        sys.exit(0)

    # Time to copy files files to the host file system
    try:
        pwd = os.getcwd()
        for file in glob.glob(pwd+'/'+ucode_dir+'/06*'):
            shutil.copyfile(file, "/lib/firmware/intel-ucode/"
                                  + os.path.basename(file))
        subprocess.check_call('echo 1 '
                              '> /sys/devices/system/cpu/microcode/reload',
                              shell=True)
    except Exception as e:
        print("FAILED: " + str(e))
        print("FAILED: Unable to load micro-code!!!")

    print("Microcode Ver: {}".format(subprocess.check_output
                                     (['rdmsr', '0x8b'])))
    print("Micro-Code Revisions:\n", open(pwd+"/"+ucode_dir+"/ucode-ver.txt", 'r').read())
    print("Init-Container Revision: %s" % open(pwd+'/init-cont-ver.txt', 'r').read())


if __name__ == '__main__':
    ucode()
