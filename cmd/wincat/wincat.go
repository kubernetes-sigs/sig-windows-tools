package main

import (
	"fmt"
	"io"
	"log"
	"net"
	"os"
)

type Result struct {
	bytes uint64
}

func copyStream(r io.ReadCloser, w io.WriteCloser, name string, done chan Result) {
	defer func() {
		r.Close()
		w.Close()
	}()
	n, err := io.Copy(w, r)
	if err != nil {
		log.Printf("error while copying stream %s: %s\n", name, err)
	}
	done <- Result{bytes: uint64(n)}
}

func main() {
	if len(os.Args) != 3 {
		log.Fatalln("usage: wincat <host> <port>")
	}
	host := os.Args[1]
	port := os.Args[2]

	conn, err := net.Dial("tcp", fmt.Sprintf("%s:%s", host, port))
	if err != nil {
		log.Fatalf(fmt.Sprintf("Failed to connect to %s:%s because %s\n", host, port, err))
	}
	results := make(chan Result)
	go copyStream(conn, os.Stdout, "stdout", results)
	go copyStream(os.Stdin, conn, "stdin", results)

	result := <-results
	log.Printf("[%s]: Connection closed by remote peer, %d bytes have been received\n", conn.RemoteAddr(), result.bytes)
	result = <-results
	log.Printf("[%s]: Local peer has been stopped, %d bytes has been sent\n", conn.RemoteAddr(), result.bytes)
}
