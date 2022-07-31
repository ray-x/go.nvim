package main

import (
	"fmt"
	"sampleApp/pkg"
)

func main() {
	i := 32
	j := 33
	result := pkg.FindAllSubStr("Find niddle in stack", "niddle")
	fmt.Println("result for find ninddle in stack: ")
	fmt.Println(result, i+j)
}
