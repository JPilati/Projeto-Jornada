const fs = require('fs');
const http = require('http');
const path = require('path');

const root = __dirname;
const port = Number(process.env.PORT || 8080);
const types = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.svg': 'image/svg+xml'
};

http.createServer((req, res) => {
  const url = new URL(req.url, `http://localhost:${port}`);
  const routeAliases = new Map([
    ['/', '/index.html'],
    ['/jornada', '/index.html'],
    ['/jornada/', '/index.html'],
    ['/jornada/index.html', '/index.html']
  ]);
  const requestedPath = routeAliases.get(url.pathname) || url.pathname;
  const filePath = path.resolve(root, `.${requestedPath}`);

  if (!filePath.startsWith(root)) {
    res.writeHead(403);
    res.end('Forbidden');
    return;
  }

  fs.readFile(filePath, (error, data) => {
    if (error) {
      res.writeHead(404);
      res.end('Not found');
      return;
    }

    res.writeHead(200, {
      'Content-Type': types[path.extname(filePath)] || 'application/octet-stream'
    });
    res.end(data);
  });
}).listen(port, '127.0.0.1', () => {
  console.log(`Jornada dashboard: http://localhost:${port}`);
});
