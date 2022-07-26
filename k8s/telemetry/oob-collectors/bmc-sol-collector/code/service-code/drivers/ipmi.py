from drivers import Driver, OutputFileWriter
import os
import multiprocessing
import subprocess
import sys
import re
import signal
import time
import pexpect

class IntelIpmi(Driver):
    """
    Class that establishes websocket session with ipmi
    """

    def __init__(self, name, target, user, password, output_directory, write_raw_files):
        super().__init__(name, target, user, password, output_directory, write_raw_files)
        self.p = None
        self._ipmitool_args = [ '-H', self.target, '-I', 'lanplus', '-U', self.user, '-P', self.password ]
        signal.signal(signal.SIGINT, self.exit_nicely)
        signal.signal(signal.SIGTERM, self.exit_nicely)

    def exit_nicely(self, signum, frame):
        try:
            if self.p:
                self.p.kill()
                self.p.wait()
        except:
             pass
        self.file_writer.log("Session Closed by the parent process")
        sys.exit(0)

    def _sol_deactivate(self):
        cmd = ['ipmitool'] + self._ipmitool_args + ['sol', 'deactivate']
        try:
            self.p = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            self.p.communicate()
        except Exception as e:
            pass
    
    def _sol_configure(self):
        cmd = ['ipmitool'] + self._ipmitool_args + ['sol', 'set', 'enabled', 'true']
        try:
            self.p = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            self.p.communicate()
        except Exception as e:
            pass

    def configure_session(self):
        self._sol_deactivate()
        self._sol_configure()

    def logout(self):
        pass

    def _escape_ansi(self, msg):
        ansi_escape = re.compile(r'(?:\x1B[@-_]|[\x80-\x9F])[0-?]*[ -/]*[@-~]')
        return ansi_escape.sub('', msg)

    def start_session(self, pipe_write):
        started = False
        try:
            cmd = self._ipmitool_args + [ 'sol', 'activate' ]
            with open(self.file_writer.get_filename_with_path(), "a") as solout:
                self.p = pexpect.spawn('ipmitool', cmd, logfile=solout,  encoding='utf-8')
                index = self.p.expect(['SOL Session operational.'])
                self.file_writer.log("Session Started")
                pipe_write.send('started')
                started = True
                self.p.expect(pexpect.EOF, timeout=None, searchwindowsize=None)
            self.file_writer.log("Session Closed")
            sys.exit(1)
        except Exception as e:
            if started: 
                self.file_writer.log("Session terminated")
            else:
                self.file_writer.log("Failed to start session")
            raise e
