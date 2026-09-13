"""Local-only fixture server; never shipped. Run from repository root."""
from http.server import SimpleHTTPRequestHandler,HTTPServer
from pathlib import Path
class Preview(SimpleHTTPRequestHandler):
 def do_GET(self):
  if self.path.split('?')[0] in ('/','/index.html'):
   html=Path('index.html').read_text().replace('<body>','<body><script src="/test/preview-fixtures.js"></script>')
   self.send_response(200);self.send_header('Content-Type','text/html; charset=utf-8');self.end_headers();self.wfile.write(html.encode())
  elif self.path.split('?')[0]=='/sw.js':
   self.send_response(200);self.send_header('Content-Type','application/javascript');self.end_headers();self.wfile.write(b'// Service worker disabled in isolated fixture preview')
  else:super().do_GET()
HTTPServer(('0.0.0.0',8765),Preview).serve_forever()
