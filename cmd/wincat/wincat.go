package main

import (
	"fmt"
	"io"
	"log"
	"net"
	"os"
	"sync"
)

func main() {
	if len(os.Args) != 3 {
		log.Fatalln("usage: wincat <host> <port>")
	}
	host := os.Args[1]
	port := os.Args[2]

	addr, err := net.ResolveTCPAddr("tcp", fmt.Sprintf("%s:%s", host, port))
	if err != nil {
		log.Fatalf("Failed to resolve TCP addr %v %v", host, port)
	}

	conn, err := net.DialTCP("tcp", nil, addr)
	if err != nil {
		log.Fatalf("Failed to connect to %s:%s because %s", host, port, err)
	}
	defer conn.Close()

	var wg sync.WaitGroup
	wg.Add(2)

	go func() {
		defer func() {
			os.Stdout.Close()
			os.Stdin.Close()
			conn.CloseRead()
			wg.Done()
		}()

		_, err := io.Copy(os.Stdout, conn)
		if err != nil {
			log.Printf("error while copying stream to stdout: %v", err)
		}
	}()

	go func() {
		defer func() {
			conn.CloseWrite()
			wg.Done()
		}()

		_, err := io.Copy(conn, os.Stdin)
		if err != nil {
			log.Printf("error while copying stream from stdin: %v", err)
		}
	}()

	wg.Wait()
}
