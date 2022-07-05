package pkg

import (
	"fmt"
	"math"
)

type Geometry interface {
	area() float64
	perim() float64
}

type rect struct {
	width  float64 `-line:"width"`
	height float64 `-line:"height"`
}

func (r rect) area() float64 {
	return r.width * r.height
}

func (r rect) perim() float64 {
	return 2*r.width + 2*r.height
}

type circle struct {
	radius float64
}

func (c circle) area() float64 {
	return math.Pi * c.radius * c.radius
}

func (c circle) perim() float64 {
	return 2 * math.Pi * c.radius
}

func measure(g Geometry) int {
	fmt.Println(g)
	fmt.Println(g.area())
	fmt.Println(g.perim())
	return 1
}
