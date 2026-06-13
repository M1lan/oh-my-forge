package main

import (
	"os"

	"omf/dispatch/internal/app"
)

func main() {
	os.Exit(app.App{}.Run(os.Args[1:]))
}
