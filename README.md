# Twisted City Life


## About 

The demo consists of a exploring a cityscape wrapped around a torusknot 

Duration: about 3 min

License: GPL

Releases at [@party[(http://atparty-demoscene.net) in June 2019

Technologies: Dart, WebGL2

Note, WebGL2 is **not** supported in Safari

## Live Version

http://art.muth.org/twisted_city_life.html 

( Developer Mode http://art.muth.org/twisted_city_life.html#develop )

## Development

Note: run `make` without arguments for more info

### Install SDK 

Ubuntu: package `dart``

Other platforms:  https://dart.dev/tutorials/web/get-started (Section 2. Install Dart)


update PATH in Makefile 

### Install Demo Dependencies

make get

### Development Build

make serve

(launches web server with just-in-time-transpiling)

Navigate to localhost:8080/delta.html

### Release Build

make build_release 

make zipball (optional)

make serve_release

Navigate to localhost:8080/delta.html

