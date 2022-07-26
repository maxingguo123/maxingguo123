#-------------------------------------------------------------------------------------------------
# Name:        Configmap Cleaner
# Purpose:     Generate a config map faster that manually.
#
# Author:      dcastr5
# Maintainer:  dcastr5
# Version:     0.1
# Created:     7/26/2020
#-------------------------------------------------------------------------------------------------
import os
import yaml
import sys

def warning_raiser():
    # SEARCH IN ALL NODES TO ADD TO FIND DUPLICATES
    # IF A DUPLICATE EXIST AND EXCEPTION WILL RAISE
    # THIS WILL STOP THE SCRIPT
    l = piv_nodes+oss_nodes+ive_nodes+infra_nodes
    duplicates = set([x for x in l if l.count(x) > 1])
    if duplicates:
        raise Exception("\nWARNING RAISER():\n  Sorry, You have duplicates in the nodes to add.\n {}".format(duplicates))
    print("WARNING RAISER():\n  THE CONFIG MAP WILL BE GENERATED.")

def get_env(set_env):
    env = os.getenv(set_env) if os.getenv(set_env) is not None else []
    if env:
        return env.split(",") if "," in env else [env]
    else:
        return []
    
def print_environment():
    print("PRINT ENVIRONMENT():\n  --LIST OF SYSTEMS SET IN ENV-- \n    INFRA: {}\n    IVE: {}\n    OSS: {}\n    PIV:{}".format(infra_nodes, ive_nodes, oss_nodes, piv_nodes))

def get_cluster(default):
    for arg in sys.argv:
        if "--cluster" in arg.lower():
            arg = arg.split("=")[1]
            if arg == "gdc-1":
                return 'machine-owners-purley.yaml'
            elif arg == "opus":
                return 'machine-owners-opus.yaml'
    return default    

def generate_configmap(configmap_file):
    # GENERATE THE YAML WITH THE NEW CHANGES
    dict_yaml = yaml.safe_load(open(configmap_file, 'r'))
    nodes = yaml.safe_load(dict_yaml["data"]["owner_file.yaml"])
    # REMOVE/ADD FROM THE SECTION THE NODES WITH CONFLICT
    cdc = [i for i in clean(nodes, "cdc") if (not i in remove_nodes + infra_nodes + piv_nodes + oss_nodes + ive_nodes) and i]
    infra = [i for i in clean(nodes, "infra") if (not i in remove_nodes + piv_nodes + oss_nodes + ive_nodes + cdc_nodes) and i]
    ive = [i for i in clean(nodes, "ive") if (not i in remove_nodes + piv_nodes + oss_nodes + infra_nodes + cdc_nodes) and i]
    oss = [i for i in clean(nodes, "oss") if (not i in remove_nodes + piv_nodes + infra_nodes + ive_nodes + cdc_nodes) and i]
    piv = [i for i in clean(nodes, "piv") if (not i in remove_nodes + infra_nodes + oss_nodes + ive_nodes + cdc_nodes) and i]
    newfile = open(get_cluster('machine-owners-icx.yaml'), 'w')
    newfile.write(init)
    newfile.write('\n    cdc:')
    for node in sorted(list(set(cdc+cdc_nodes))):
        newfile.write('\n      {}:'.format(node))
    newfile.write('\n    infra:')
    for node in sorted(list(set(infra+infra_nodes))):
        newfile.write('\n      {}:'.format(node))
    newfile.write('\n    ive:')
    for node in sorted(list(set(ive+ive_nodes))):
        newfile.write('\n      {}:'.format(node))
    newfile.write('\n    oss:')
    for node in sorted(list(set(oss+oss_nodes))):
        newfile.write('\n      {}:'.format(node))
    newfile.write('\n    piv:')
    for node in sorted(list(set(piv+piv_nodes))):
        newfile.write('\n      {}:'.format(node))
    newfile.write('\n')
    

def clean(nodes, owner):
    # CLEAN THE RESULT FROM THE YAML LOAD DICT SECTIONS AND RETURN A CLEAN LIST
    return [] if nodes[owner] is None else [key for key,value in nodes[owner].items()]

def git_diff():
    print("GIT DIFF():")
    os.system("git diff %s" %get_cluster('machine-owners-icx.yaml'))
    print("\n\nIf you want to discarg the changes please run:\ngit checkout @ -- %s" %get_cluster('machine-owners-icx.yaml'))

# OPTIONAL: REMOVE NODES FROM ALL THE YAML
remove_nodes = get_env("REMOVE_NODES")
# NODES TO ADD IN SECTIONS PIV,OSS,IVE,INFRA
piv_nodes = get_env("PIV_NODES")
oss_nodes = get_env("OSS_NODES")
cdc_nodes = get_env("CDC_NODES")
ive_nodes = get_env("IVE_NODES")
infra_nodes = get_env("INFRA_NODES")
# INIT FILE FOR THE CONFIG MAP, DO NOT TOUCH
init = '''apiVersion: v1
kind: ConfigMap
metadata:
  name: machine-owners-list
  namespace: mgmt
data:
  owner_file.yaml: |-'''

if __name__ == "__main__":
    configmap_file = get_cluster('machine-owners-icx.yaml')
    print_environment()
    warning_raiser()
    generate_configmap(configmap_file)
    git_diff()




