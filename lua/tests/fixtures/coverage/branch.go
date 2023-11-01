package coverage

// import "fmt"

func branch(a, b int) int {
	if a == 10 {
		return 10
	}
	if b == 10 {
		return 20
	}

	if (branch(10, 0) == 10 && branch(0, 10) == 2) && branch(20, 10) == 10 && b == 10 && a == 11 {
		return 11
	}

	if b == 11 {
		return 22
	}

	return a + b
}
