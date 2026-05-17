from http.server import SimpleHTTPRequestHandler, HTTPServer
import os
os.chdir(r'A:\Gamejam\Spacejam\return-to-work-plz\CodeReport')
class Handler(SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            html = '<html><body>'
            for file in os.listdir('.'):
                if file.endswith('.png'):
                    html += f'<h1>{file}</h1><img src=\"{file}\" width=\"800\"><br>'
            html += '</body></html>'
            self.wfile.write(html.encode('utf-8'))
        else:
            super().do_GET()
print("Serving on port 8080")
HTTPServer(('', 8080), Handler).serve_forever()
