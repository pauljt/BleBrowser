"""
Run an HTTPS server serving the contents of the directory.

You'll need to generate a key and certificate file. On a Mac you should do this by following
the instructions in:

https://developer.apple.com/library/archive/technotes/tn2326/_index.html

First "Creating a Certificate Authority" and then "Issuing a [server] Digital Identity"

This will generate a self-signed root Certificate Authority (CA) certificate and a signed server
certificate (digital identity) to be used by your server.

You then need to export the certificate authority certificate
as a .cer file through KeyChain by

- right click the CA certificate
- hit Export...
- select the .cer format

Then add it to you test iOS device by

- emailing it to yourself
- tapping on the .cer attachment
- installing it and trusting it
- enabling it through Settings -> General -> About -> Certificate Trust Settings

Then you need to export the signed server cert, this time using format
"Personal Information Exchange" (.p12) so that it includes the private key, then convert it to
pem using openssl like this:

    openssl pkcs12 -in your-export.p12 -nocerts -nodes -out your-server.key
    openssl pkcs12 -in your-export.p12 -nokeys -nodes -out your-server.cer

You can then run this server like this:

    python3 https.py --host 192.168.1.102 --port 4443 your-server.key your-server.cer
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
