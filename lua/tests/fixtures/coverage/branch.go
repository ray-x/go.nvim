package main

// import "fmt"

func branch(a, b int) int {
	if a == 10 {
		return 10
	}
	if b == 10 {
		return 20
	}

	if a == 11 {
		return 11
	}

	if b == 11 {
		return 22
	}

	return a + b
}
