// https://gobyexample.com/interfaces
//
package main

import (
	"fmt"
)

type Geometry interface {
	Area() float64
	perim() float64
}

type rect struct {
	width, height float64
}

func (r rect) Area() float64 {
	return r.width * r.height
}

func (r rect) perim() float64 {
	return 2*r.width + 2*r.height
}

func (r rect) test_print() {
	fmt.Println(r.perim())
}

func measure(g Geometry) {
	fmt.Println(g)
	fmt.Println(g.Area())
	fmt.Println(g.perim())
}

func main() {
	r := rect{width: 3, height: 4}
	measure(r)
	r.test_print()
}
