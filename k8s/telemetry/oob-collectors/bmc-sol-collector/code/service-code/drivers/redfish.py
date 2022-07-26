from drivers import Driver, OutputFileWriter
import os
import websocket
import urllib3
import requests
import socket
import json
import selectors
import re
import signal
import ssl


class AtscaleSSLDispatcher:
    def __init__(self, app, ping_timeout):
        self.app = app
        self.ping_timeout = ping_timeout

    def read(self, sock, read_callback, check_callback):
        while self.app.keep_running:
            r = self.select()
            if r:
                if not read_callback():
                    break
            check_callback()

    def select(self):
        sock = self.app.sock.sock
        if sock.pending():
            return [sock,]

        sel = selectors.DefaultSelector()
        sel.register(sock, selectors.EVENT_READ)
        r = sel.select(self.ping_timeout)
        sel.close()

        if len(r) > 0:
            return r[0][0]


class IntelRedfish(Driver):
    """
    Class that establishes websocket session with OpenBmc
    """

    REQUEST_TIMEOUT=10
    PING_TIMEOUT=15
    PING_INTERVAL=20
    NEW_LINE_FEED = re.compile(r'[\x0a\x0c\x0d]')
    # replace cursor movement characters with new lines
    POSITION_ASCII_CHARACTERS = re.compile(r'\x1B\[[0-9]+;[0-9]+[Hf]{1}')
    # all other ascii control characters
    ESCAPE_ASCII_CHARACTERS = re.compile(r'(?:\x1B[@-_]|[\x80-\x9F])[0-?]*[ -/]*[@-~]')

    def __init__(self, name, target, user, password, output_directory, write_raw_files):
        super().__init__(name, target, user, password, output_directory, write_raw_files)
        urllib3.disable_warnings()
        self.headers = {
            'Content-Type': 'application/json; charset=UTF-8'
        }
        signal.signal(signal.SIGINT, self.exit_by_parent)
        signal.signal(signal.SIGTERM, self.exit_by_parent)

    def _copy_xsrf_token_to_header(self):
        for cookie in self.session.cookies:
            if cookie.name == 'XSRF-TOKEN':
                self.headers['X-XSRF-TOKEN'] = cookie.value

    def exit_by_parent(self, signum, frame):
        self.file_writer.log("Session closed by the parent process")
        self.logout()
        try:
            self.ws.keep_running = False
        except:
            pass
        os._exit(0)


    def exit_on_close(self):
        self.file_writer.log("Graceful exit")
        self.logout()
        try:
            self.ws.keep_running = False
        except:
            pass
        os._exit(0)

    def get_auth_cookie(self):
        token = ""
        session = ""
        for cookie in self.session.cookies:
            if cookie.name == 'XSRF-TOKEN':
                token = cookie.value
            elif cookie.name == 'SESSION':
                session = cookie.value
        cookie = "XSRF-TOKEN={}; SESSION={};".format(token, session)
        return cookie

    def configure_session(self):
        try:
            self.session = requests.Session()
            payload = {'data': [self.user, self.password]}
            url = "https://{}/login".format(self.target)
            r = self.session.post(url, data=json.dumps(payload), headers=self.headers, verify=False, timeout=IntelRedfish.REQUEST_TIMEOUT)
            self._copy_xsrf_token_to_header()
        except Exception as e:
            self.file_writer.log("Login failed: {}".format(e))
            raise e

    def logout(self):
        try:
            url = "https://{}/logout".format(self.target)
            self.session.post(url, headers=self.headers, verify=False, timeout=IntelRedfish.REQUEST_TIMEOUT)
        except:
            pass

    def _escape_ansi(self, msg):
        with_newlines = IntelRedfish.POSITION_ASCII_CHARACTERS.sub('\n', msg)
        escaped = IntelRedfish.ESCAPE_ASCII_CHARACTERS.sub('', with_newlines)
        escaped = IntelRedfish.NEW_LINE_FEED.sub('\n', escaped)
        return escaped

    def start_session(self, pipe_write):
        cookie = self.get_auth_cookie()
        url = "wss://{}/console0".format(self.target)
        def on_open(ws):
            self.file_writer.log("Session Started (pid={})".format(os.getpid()))
            pipe_write.send('started')
        
        def on_error(ws, error):
            self.file_writer.log("Websocket error: {}".format(error))

        def on_close(ws):
            self.file_writer.log("Session closed (pid={})".format(os.getpid()))
            self.exit_on_close()

        def on_message(ws, message):
            decoded_msg = message.decode()
            if self.raw_writer:
                self.raw_writer.write(decoded_msg)
            escaped = self._escape_ansi(decoded_msg)
            self.file_writer.write(escaped)

        try:
            self.ws = websocket.WebSocketApp(url, cookie=cookie, subprotocols=[self.headers['X-XSRF-TOKEN']])
            self.ws.on_open = on_open
            self.ws.on_error = on_error
            self.ws.on_close = on_close
            self.ws.on_message = on_message
            self.ws.run_forever(ping_interval=IntelRedfish.PING_INTERVAL, ping_timeout=IntelRedfish.PING_TIMEOUT,
                                sslopt={"cert_reqs": ssl.CERT_NONE},
                                sockopt=((socket.IPPROTO_TCP, socket.TCP_NODELAY, 1),),
                                dispatcher=AtscaleSSLDispatcher(self.ws, IntelRedfish.PING_TIMEOUT))
            self.ws.keep_running = False
            os._exit(0)
        except Exception as e:
            self.file_writer.log("Session Terminated: {}".format(e))
            raise e
