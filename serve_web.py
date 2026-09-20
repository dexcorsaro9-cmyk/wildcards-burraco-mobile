import http.server
import socketserver
import os
import sys

PORT = 8080
DIRECTORY = os.path.join(os.path.dirname(__file__), 'build', 'web')

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def end_headers(self):
        # Header essenziali per Godot 4 WebAssembly & SharedArrayBuffer
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        self.send_header('Cache-Control', 'no-cache')
        super().end_headers()

if not os.path.exists(DIRECTORY):
    os.makedirs(DIRECTORY, exist_ok=True)

print(f'Server WebApp avviato su:')
print(f' -> Dal PC: http://localhost:{PORT}')
print(f' -> Dal telefono (Wi-Fi): http://192.168.1.93:{PORT}')
print('Premi Ctrl+C per fermare il server.')

socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(('0.0.0.0', PORT), Handler) as httpd:
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print('\nServer arrestato.')
