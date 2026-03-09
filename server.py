#!/usr/bin/env python3
import http.server
import socketserver
import os
import urllib.parse

PORT = 8000
DIRECTORY = os.path.dirname(os.path.abspath(__file__))

class MyHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def _mode_from_path(self):
        path = urllib.parse.urlsplit(self.path).path
        if path.startswith("/plain/"):
            return "plain"
        return "isolated"

    def _strip_mode_prefix(self, path):
        parsed = urllib.parse.urlsplit(path)
        clean_path = parsed.path
        for prefix in ("/plain/", "/isolated/"):
            if clean_path.startswith(prefix):
                clean_path = "/" + clean_path[len(prefix):]
                break
        return urllib.parse.urlunsplit(("", "", clean_path, parsed.query, parsed.fragment))

    def do_GET(self):
        if self.path in ("/plain", "/isolated"):
            self.send_response(301)
            self.send_header("Location", self.path + "/")
            self.end_headers()
            return
        super().do_GET()

    def translate_path(self, path):
        # Keep one physical workspace, but expose two virtual URL roots:
        # /isolated/* and /plain/*
        path = self._strip_mode_prefix(path)
        return super().translate_path(path)

    def end_headers(self):
        if self._mode_from_path() == "isolated":
            # Required for SharedArrayBuffer in modern browsers.
            self.send_header("Cross-Origin-Opener-Policy", "same-origin")
            self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        super().end_headers()

if __name__ == "__main__":
    with socketserver.ThreadingTCPServer(("", PORT), MyHTTPRequestHandler) as httpd:
        print(f"Server running at http://localhost:{PORT}/")
        print(f"Serving files from: {DIRECTORY}")
        print("Isolated mode (with COOP/COEP): http://localhost:8000/isolated/index.html")
        print("Plain mode (without COOP/COEP):   http://localhost:8000/plain/index.html")
        print("Press Ctrl+C to stop the server")
        httpd.serve_forever()
