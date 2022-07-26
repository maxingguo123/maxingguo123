from abc import abstractmethod
import logging
import logging.handlers
import os
import base64
import multiprocessing
import sys
import time
import re


class Driver():

    def __init__(self, name, target, user, password, output_directory, write_raw_files):
        self.file_writer = OutputFileWriter(name, output_directory)
        self.raw_writer = None
        if write_raw_files:
            self.raw_writer = UnbufferedRawFileWriter(name, output_directory)
        self.name = name
        self.target = target
        self.user = user
        self.password = password
    
    @abstractmethod
    def start_session(self, pipe_write):
        pass

    @abstractmethod
    def configure_session(self):
        pass


class SolSessionManager():
    """
    Class that represents a single UNIX process that keeps the websocket SOL session with individual node.
    """

    def __init__(self, name, target, user, password, output_directory, driver_name, write_raw_files):
        self.name = name
        self.target = target
        self.user = base64.b64decode(user.encode('utf-8')).decode()
        self.password = base64.b64decode(password.encode('utf-8')).decode()
        self.output_directory = output_directory
        self.session_started = False
        self.driver = self._load_driver(driver_name)
        self.write_raw_files = write_raw_files

    def _load_driver(self, driver_name):
        import importlib
        import inspect
        driver = importlib.import_module(f'.{driver_name}', 'drivers')
        drivers = [(name, cls) for name, cls in inspect.getmembers(driver, inspect.isclass)
                   if issubclass(cls, Driver) and cls != Driver]
        if not drivers:
            raise ImportError('No drivers found')
        if len(drivers) > 1:
            raise ImportError('More than one driver found. Set driver argument explicit')
        name, driver = drivers.pop()
        return driver

    def _get_epoch(self):
        return int(time.time())

    def _check_if_session_started(self):
        if not self.session_started:
            try:
                if self.pipe_read and self.pipe_read.poll():
                    # there is only one message type transferred over this pipe - ignore the content
                    self.pipe_read.recv()
                    self.session_started = True
            except Exception as ess:
                pass

    def health_ok(self):
        """ Process is alive & child reported that the sol session started """
        self._check_if_session_started()

        if self.p.is_alive() and self.session_started:
            return 1.0
        else:
            return 0.0

    def is_alive(self):
        try:
            return self.p.is_alive()
        except:
            return False

    def start(self):
        (self.pipe_read, pipe_write) = multiprocessing.Pipe(duplex=False)

        self.p = multiprocessing.Process(target=self._sol_session,
                                         args=(self.name, self.target, self.user, self.password, self.output_directory,
                                               pipe_write, self.driver, self.write_raw_files))
        self.p.start()

    def close(self):
        try:
            if self.is_alive():
                self.p.terminate()
        except Exception as te:
            print("Exception while terminating a SOL subprocess: {}".format(te))

    def _sol_session(self, name, target, user, password, output_directory, pipe_write, driver, write_raw_files):
        iub = driver(name, target, user, password, output_directory, write_raw_files)
        try:
            iub.configure_session()
            iub.start_session(pipe_write)
        except:
            sys.exit(1)
        finally:
            iub.logout()


class OutputFileWriter:
    """
    Class that generates file names in the format: $OUTPUT_DIR/$NODE
    """

    def __init__(self, name, output_directory):
        filename = "{}.log".format(os.path.join(output_directory, name))
        handler = logging.handlers.RotatingFileHandler(filename, mode='a', maxBytes=10485760, backupCount=2)
        self.logger = logging.getLogger("Rotating Log")
        self.logger.setLevel(logging.INFO)
        self.logger.addHandler(handler)
        self.name = name
        self.start_time = int(time.time())
        self.buffer = []
        self.count = 1

    def _line_is_blank(self, msg):
        return len(msg) == 0 or re.match(r'^[ \t]+$', msg)

    def write_logline(self, msg):
        if not self._line_is_blank(msg):
            time_ns = time.time()
            self.logger.info("{} - {} - {} - {:.6f} - {}".format(self.name, self.start_time, self.count, time_ns, msg))
            self.count += 1

    def log(self, msg):
         self.write_logline("SolUpenBmc: {}".format(msg))

    def _is_last_line(self, idx, messages):
        return idx+1 == len(messages)

    def save_to_buffer(self, message):
        self.buffer.append(message)

    def read_from_buffer(self):
        return "".join(self.buffer)

    def clear_buffer(self):
        self.buffer = []

    def write(self, msg):
        """ Redfish data is transfered in frames and sometimes one line comes in 2 messages. We need to buffer them. """
        messages = msg.split("\n")
        for lineno, message in enumerate(messages):
            if self._is_last_line(lineno, messages):
                self.save_to_buffer(message)
            else:
                buffer = self.read_from_buffer()
                self.clear_buffer()
                self.write_logline("{}{}".format(buffer, message))


class UnbufferedRawFileWriter:
    """
    Class that generates file names in the format: $OUTPUT_DIR/$NODE.raw
    """

    def __init__(self, name, output_directory):
        filename = "{}.raw".format(os.path.join(output_directory, name))
        handler = logging.handlers.RotatingFileHandler(filename, mode='a', maxBytes=10485760, backupCount=3)
        self.name = name
        self.start_time = int(time.time())
        self.logger = logging.getLogger("Raw Log: {}".format(self.start_time))
        self.logger.setLevel(logging.INFO)
        self.logger.addHandler(handler)

    def write(self, msg):
        time_ns = time.time()
        self.logger.info("{:.6f}:{}".format(time_ns, msg))