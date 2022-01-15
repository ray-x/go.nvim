package main

import (
	"fmt"
	"sampleApp/pkg"
)

func main() {
	result := pkg.FindAllSubStr("Find niddle in stack", "niddle")
	fmt.Println(result)
}
