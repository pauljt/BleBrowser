"""
Run an HTTPS server serving the contents of the directory.

You'll need to generate a key and certificate file, which for development purposes can be
self-signed, something like:

    openssl \
        req \
        -x509 \
        -newkey rsa:4096 \
        -keyout key.pem \
        -out cert.pem \
        -sha256 \
        -nodes \
        -subj '/CN=localhost' \  # or whatever local domain name you wish to use
        -days 365

Then to install it simply email yourself the cert.pem file.
"""
import argparse
import http.server
import ssl




if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Run an HTTPS server to serve your current directory')
    parser.add_argument('keyfile')
    parser.add_argument('certfile')
    parser.add_argument('--host', default='localhost')
    parser.add_argument('--port', type=int, default=4443)
    args = parser.parse_args()

    print(f'Binding to {args.host}:{args.port}')
    httpd = http.server.HTTPServer(
        (args.host, args.port), http.server.SimpleHTTPRequestHandler
    )
    print(f'Using keyfile {args.keyfile}')
    print(f'Using certificate {args.certfile}')
    httpd.socket = ssl.wrap_socket(
        httpd.socket,
        keyfile=args.keyfile,
        certfile=args.certfile,
        server_side=True,
    )
    httpd.serve_forever()
