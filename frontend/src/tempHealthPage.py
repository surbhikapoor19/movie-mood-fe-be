from http.server import BaseHTTPRequestHandler, HTTPServer
import json

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"status": "starting"}).encode())
        else:
            self.send_response(404)
            self.end_headers()

HTTPServer(("0.0.0.0", 9010), Handler).serve_forever()