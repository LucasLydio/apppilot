const http = require("http");

const port = process.env.PORT || 18080;
http
  .createServer((req, res) => {
    res.writeHead(200, { "content-type": "application/json" });
    res.end(JSON.stringify({ ok: true, path: req.url }));
  })
  .listen(port, "127.0.0.1");
