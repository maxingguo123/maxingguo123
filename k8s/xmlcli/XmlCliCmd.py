#!/usr/bin/env python
#################################################################################
# INTEL CONFIDENTIAL
# Copyright Intel Corporation All Rights Reserved.
#
# The source code contained or described herein and all documents related to
# the source code ("Material") are owned by Intel Corporation or its suppliers
# or licensors. Title to the Material remains with Intel Corporation or its
# suppliers and licensors. The Material may contain trade secrets and proprietary
# and confidential information of Intel Corporation and its suppliers and
# licensors, and is protected by worldwide copyright and trade secret laws and
# treaty provisions. No part of the Material may be used, copied, reproduced,
# modified, published, uploaded, posted, transmitted, distributed, or disclosed
# in any way without Intel's prior express written permission.
#
# No license under any patent, copyright, trade secret or other intellectual
# property right is granted to or conferred upon you by disclosure or delivery
# of the Materials, either expressly, by implication, inducement, estoppel or
# otherwise. Any license under such intellectual property rights must be express
# and approved by Intel in writing.
#################################################################################
import argparse
import os
import re
import subprocess
import sys
import time
from io import StringIO
from contextlib import redirect_stdout

import pysvtools.xmlcli.XmlCli as XmlCli


class XmlCliCmd(object):
    """XmlCli wrapper class for container-based configuration and execution"""

    # XmlCli log validation patterns
    XMLCLI_FAIL_PATTERNS = [re.compile(pat) for pat in [r"does not currently exist",
                                                        r"Aborting...",
                                                        r"Verify Fail",
                                                        r"Verify Failed",
                                                        r"fail",
                                                        r"is not in proper format"]]

    # Patterns that flag if a knob change is pending (system needs restart)
    XMLCLI_READ_UNPROGRAMMED_PATTERNS = [re.compile(r"PowerGoodResetRequired")]

    # Pattern that can extract knob names, settings, etc. from the XmlCli output
    # VI - Offset - Knob Name - Size - Default Value - Current Value
    XMLCLI_KNOB_PATTERN = re.compile(
        r"\|\s*([0-9A-F]+)\|\s*([0-9A-F]+)\|\s*([A-z0-9]+)\|\s*([0-9A-F]+)\|\s*([0-9A-F]+)\s*\|\s*([0-9A-F]+)\s*\|")
    INI_KNOB_PATTERN = re.compile(r"^([0-9A-z]+)=([0-9A-z]+)$")

    class XmlCliCommands:
        def __init__(self):
            pass
        READ_KNOBS = "readknobs"
        PROGRAM_KNOBS = "progknobs"
        LOAD_DEFAULTS = "loaddefaults"
        RESTORE_MODIFY_KNOBS = "restoremodify"
        SAVE_XML = "savexml"

    def __init__(self, quiet=False):
        # noinspection PyProtectedMember
        XmlCli.clb._setCliAccess("linux")
        self.quiet_mode = quiet

    def _verify_xmlcli_output(self, output, extra_validation_patterns=None):
        status = True
        if extra_validation_patterns is not None:
            fail_pattern_list = self.XMLCLI_FAIL_PATTERNS + extra_validation_patterns
        else:
            fail_pattern_list = self.XMLCLI_FAIL_PATTERNS

        for line in output.split(os.linesep):
            for pat in fail_pattern_list:
                if pat.search(line):
                    print("Found failing string: {}".format(line))
                    status = False
        return status

    def _verify_knob_settings(self, input_knob_str, output):
        # Extract XmlCli reported knobs from output
        reported_knobs = {}
        for line in output.split(os.linesep):
            knob_match = self.XMLCLI_KNOB_PATTERN.match(line)
            if knob_match:
                reported_knobs[knob_match.group(3)] = knob_match.group(6)  # Associate reported knob value with name

        # Extract desired settings from input
        input_knobs = {}
        for knob_str in input_knob_str.split(","):
            knob, setting = knob_str.split("=")
            input_knobs[knob] = setting if not setting.startswith("0x") else setting[2:]

        # Ensure that each knob was set as expected
        status = input_knobs == reported_knobs
        if not status:
            print("XmlCli output did not match the expected values!")
            print("xmlcli_expected: {}".format(input_knobs))

        print("xmlcli_readback: {}".format(reported_knobs))

        return status

    def _extract_knob_string_from_ini(self, ini_file="/xmlcli/pysvtools/xmlcli/cfg/BiosKnobs.ini"):
        knob_list = []
        for line in open(ini_file, "r").readlines():
            knob_match = self.INI_KNOB_PATTERN.match(line)
            if knob_match:
                knob_list.append(line.strip())
        knob_string = ",".join(knob_list)
        print("Using knob spec from ini file: {}".format(knob_string))
        return knob_string

    def readknobs(self, knobs):
        """
        Checks the current BIOS configuration against specified knobs or the XmlCli ini file (discouraged).

        The knob string should be formatted like this: "KnobName1=0,KnobName2=1", etc.
        :param knobs: Comma-delimited string of knobs and expected values
        :return: Status code of XmlCli API call
        """
        # Run XmlCli to read knob settings
        with StringIO() as buf, redirect_stdout(buf):
            status = XmlCli.CvReadKnobs(KnobStr=(0 if knobs == "" else knobs))
            xmlcli_output = buf.getvalue()

        # Apply extra validation that XmlCli itself doesn't
        xmlcli_return_status = status == 0 and \
            self._verify_xmlcli_output(xmlcli_output, self.XMLCLI_READ_UNPROGRAMMED_PATTERNS)
        knob_str = knobs if knobs != "" else self._extract_knob_string_from_ini()

        try:
            xmlcli_knob_status = self._verify_knob_settings(knob_str, xmlcli_output)
        except ValueError as e:
            print("Error verifying knob status: {}".format(e))
            xmlcli_knob_status = False

        final_result = 0 if xmlcli_return_status and xmlcli_knob_status else 1

        if not self.quiet_mode:
            print(xmlcli_output)

        # Determine final result
        return final_result

    def loaddefaults(self):
        """
        Loads default values for all BIOS knobs

        :return: Status code of XmlCli API call
        """
        return XmlCli.CvLoadDefaults()

    def progknobs(self, knobs):
        """
        Sets the BIOS knobs in the knob string or XmlCli ini file (discouraged) to the given values.

        The knob string should be formatted like this: "KnobName1=0,KnobName2=1", etc.
        :param knobs: Comma-delimited string of knobs and expected values
        :return: Status code of XmlCli API call
        """
        # Run XmlCli to program knob settings
        with StringIO() as buf, redirect_stdout(buf):
            status = XmlCli.CvProgKnobs(KnobStr=(0 if knobs == "" else knobs))
            xmlcli_output = buf.getvalue()

        # Apply extra validation that XmlCli itself doesn't
        xmlcli_return_status = status == 0 and self._verify_xmlcli_output(xmlcli_output)
        knob_str = knobs if knobs != "" else self._extract_knob_string_from_ini()

        try:
            xmlcli_knob_status = self._verify_knob_settings(knob_str, xmlcli_output)
        except ValueError as e:
            print("Error verifying knob status: {}".format(e))
            xmlcli_knob_status = False

        final_result = 0 if xmlcli_return_status and xmlcli_knob_status else 1

        if not self.quiet_mode:
            print(xmlcli_output)

        # Determine the final result
        return final_result

    def restoremodify(self, knobs):
        """
        Restores BIOS knobs to default values and then modifies the specified knobs to the given values.

        The knob string should be formatted like this: "KnobName1=0,KnobName2=1", etc.
        :param knobs: Comma-delimited string of knobs and expected values
        :return: Status code of XmlCli API call
        """
        # TODO: Apply extra validation to restoremodify
        return XmlCli.CvRestoreModifyKnobs(KnobStr=(0 if knobs == "" else knobs))

    def savexml(self):
        """
        Download PlatformConfig.xml from the BIOS.

        :return: Status code of XmlCli API call
        """
        return XmlCli.savexml()

    @classmethod
    def xml_cli_cmd(cls):
        """
        Main method for running XmlCli API commands.

        If importing this class to use in other scripts, do not call this method, as it will hang the Python interpreter
        if configured to do so.
        :return: XmlCli status code for user-specified XmlCli API call
        """
        pull_from_env = "environment"
        supported_commands = [cls.XmlCliCommands.READ_KNOBS, cls.XmlCliCommands.PROGRAM_KNOBS,
                              cls.XmlCliCommands.LOAD_DEFAULTS, cls.XmlCliCommands.RESTORE_MODIFY_KNOBS,
                              cls.XmlCliCommands.SAVE_XML, pull_from_env]
        arg_parser = argparse.ArgumentParser()
        arg_parser.add_argument("operation", choices=supported_commands)
        arg_parser.add_argument("-k", "--knob_str", default="", help="Python string of knobs to check or program. "
                                                                     "Should only be provided when operation is "
                                                                     "readknobs, progknobs, or restoremodify.")
        arg_parser.add_argument("-q", "--quiet", default=False, action="store_true",
                                help="When True, only print out TAP and dict of the readback. Not recommended outside"
                                     "of monitor mode, since XmlCli output will be lost.")
        arguments = arg_parser.parse_args()
        pulled_from_env = False

        if arguments.operation == pull_from_env:
            print("# Ignoring command line arguments, using XC_OP and XC_KNOB...")
            arguments.operation = os.getenv("XC_OP")
            arguments.knob_str = os.getenv("XC_KNOB")
            if arguments.operation is None or (arguments.operation in [cls.XmlCliCommands.READ_KNOBS,
                                                                       cls.XmlCliCommands.PROGRAM_KNOBS,
                                                                       cls.XmlCliCommands.RESTORE_MODIFY_KNOBS]
                                               and arguments.knob_str is None):
                raise RuntimeError("XC_OP and XC_KNOB not specified properly!")
            pulled_from_env = True
        elif arguments.knob_str != "" \
                and arguments.operation not in [cls.XmlCliCommands.READ_KNOBS, cls.XmlCliCommands.PROGRAM_KNOBS,
                                                cls.XmlCliCommands.RESTORE_MODIFY_KNOBS]:
            raise ValueError("knob_str doesn't do anything unless the operation is readknobs or progknobs!")

        cli = cls(arguments.quiet)
        if arguments.operation in [cls.XmlCliCommands.READ_KNOBS, cls.XmlCliCommands.PROGRAM_KNOBS,
                                   cls.XmlCliCommands.RESTORE_MODIFY_KNOBS]:
            status = cli.__getattribute__(arguments.operation)(arguments.knob_str)
        else:
            status = cli.__getattribute__(arguments.operation)()

        if status != 0:
            print("not ok 1 - xmlcli")  # Kill the k8s wait if it failed
        else:
            print("ok 1 - xmlcli")
            subprocess.call(["touch", "/tmp/testdone"])

        if pulled_from_env and os.getenv("XC_BYPASS_HANG") is None:
            sys.stdout.flush()
            while True:
                time.sleep(10.0)
                pass

        return status


if __name__ == '__main__':
    try:
        xmlcli_status = XmlCliCmd.xml_cli_cmd()
    except Exception:
        print("not ok 1 - xmlcli")  # Ensure that not ok is printed, even if there is an unexpected exception
        raise
    sys.exit(xmlcli_status)
