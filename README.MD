# Demo DB Service
This is a sample application which queries a simple database for names and serves those names from a web server.

## Compiling Go source code
Make sure Go is installed. To compile `main.go` into the binary `app`, use the following command:  
```go build -o app main.go```.

Alternatively, you can use a multi-stage Docker build if you do not want to install Go locally.
