#!/usr/bin/env python3

import copy
import inotify.adapters
import json
import os
import subprocess
import time
import yaml

CPUCOUNT = os.cpu_count()
all_msrs = {}
SLEEPTIME = int(os.environ.get("SLEEPTIME")) \
        if os.environ.get("SLEEPTIME") else int(3600)
MSR_IN_FILE = os.environ.get("MSR_IN_FILE") \
        if os.environ.get("MSR_IN_FILE") else "/configmaps/msrs"
MSR_OUT_FILE = os.environ.get("MSR_OUT_FILE") \
        if os.environ.get("MSR_OUT_FILE") else "/hostroot/k8-msrs"


def check_msrs(inputmsr: str, check_flip: bool = False):

    inmsr = inbit = inwval = None
    # Find all info about the MSR
    try:
        inmsr = (inputmsr.split(',')[0]).strip()
        inbit = (inputmsr.split(',')[1]).strip()
        inwval = (inputmsr.split(',')[2]).strip()
    except IndexError:
        pass

    read_msr_cmd = ['rdmsr', '-a']
    read_msr_cmd.append("0x{}".format(inmsr))
    if inbit is not None and inbit != "":
        read_msr_cmd.extend(['--bitfield', inbit])

    print("Read MSR {} : {}".format(inmsr, inbit))
    cmd_out = subprocess.run(read_msr_cmd,
                             stdout=subprocess.PIPE)
    msrs = list(cmd_out.stdout.decode().splitlines())

    if len(msrs) != CPUCOUNT:
        print("Unable to read all msrs")

    # The key here is a string, cause when we read back from the file it comes
    # as a string and that bites us when comparing
    msr_dict = {str(i): msrs[i] for i in range(len(msrs))}

    if check_flip:
        if inputmsr in all_msrs:
            print("Comparing previous values of {}".format(inputmsr))
            if len(set(all_msrs[inputmsr].items())
                    & set(msr_dict.items())) != CPUCOUNT:

                msr_diff = [i for i in all_msrs[inputmsr]
                            if i in all_msrs[inputmsr]
                            and all_msrs[inputmsr][i] != msr_dict[i]]

                diff_output = ""
                for key in msr_diff:
                    diff_output += " CPU {} from {} to {}, ".format(
                            key, all_msrs[inputmsr][key], msr_dict[key])

                print("MSR flipped {} : {}\n".format(
                    inputmsr, diff_output))

                # Flush the register if requested
                if inwval is not None and inwval != "":
                    write_msr_cmd = ["wrmsr", "-a"]
                    write_msr_cmd.append("0x{}".format(inmsr))
                    write_msr_cmd.append("0x{}".format(inwval))

                    print("Writing MSR {} with val {}".format(
                        inmsr, inwval))
                    try:
                        subprocess.check_call(write_msr_cmd)
                    except subprocess.CalledProcessError as e:
                        print("Unable to write msr {} with value {}. \
                                Error is {}".format(inmsr, inwval, str(e)))
    else:
        # Print a summary of the MSR values
        msr_summary = {}
        for k in msr_dict:
            try:
                msr_summary[str(msr_dict[k])].append(k)
            except KeyError:
                msr_summary[msr_dict[k]] = [k]
        print("MSR {} has values {}\n".format(
            inputmsr, msr_summary))
    # Copy the current reading into the file irrespective of it's prior
    # existance in the json
    all_msrs[inputmsr] = copy.deepcopy(msr_dict)

    # Always write to the file
    with open(MSR_OUT_FILE, 'w') as f:
        json.dump(all_msrs, f)


def read_all_msrs():
    if os.path.isfile(os.path.abspath(MSR_IN_FILE)):
        msr_to_read = yaml.safe_load(open(MSR_IN_FILE, 'r'))

        # Read Monitoring MSRs first
        try:
            for monitor_msr in msr_to_read["monitor"]:
                check_msrs(str(monitor_msr), False)
        except KeyError:
            print("No monitor keys")
            pass

        # Read the MSRs that we would like to monitor for change
        try:
            for check_msr in msr_to_read["check_change"]:
                check_msrs(str(check_msr), True)
        except KeyError:
            print("No change check MSRs")
            pass
    else:
        print("Input file {} not present.".format(MSR_IN_FILE))


def main():
    # Enable inotify on the input file to allow configmap updates in Kubernetes
    i = inotify.adapters.Inotify()
    i.add_watch(MSR_IN_FILE, mask=inotify.constants.IN_MODIFY)

    # Check if the output file exists. If it does, read the file into the
    # dictionary
    if os.path.isfile(os.path.abspath(MSR_OUT_FILE)):
        print("{} file exists. Reading data..".format(MSR_OUT_FILE))
        with open(MSR_OUT_FILE, 'r') as f:
            global all_msrs
            all_msrs = json.load(f)

    # Let us read all the msrs once.
    read_all_msrs()

    # Now we sleep and read periodically or when the MSR list file gets updated
    start_time = time.time()
    while True:
        if ((time.time() - start_time) > SLEEPTIME) \
                or next(i.event_gen(yield_nones=True)) is not None:
            read_all_msrs()
            start_time = time.time()
        time.sleep(30)


if __name__ == "__main__":
    main()
