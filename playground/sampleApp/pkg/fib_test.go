package pkg

import (
	"strconv"
	"testing"
)

func Fib(n string) string {
	nn, _ := strconv.Atoi(n)
	if nn < 2 {
		r := strconv.Itoa(nn)
		return r
	}
	n1, _ := strconv.Atoi(Fib(strconv.Itoa(nn - 1)))
	n2, _ := strconv.Atoi(Fib(strconv.Itoa(nn - 2)))
	return strconv.Itoa(n1 + n2)
}

func BenchmarkFib10(b *testing.B) {
	// run the Fib function b.N times
	for n := 0; n < b.N; n++ {
		Fib("10")
	}
}
