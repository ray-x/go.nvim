package main

import (
	"fmt"

	"sampleApp/pkg"
)

type ioRImpl struct{}

func (iorimpl *ioRImpl) Read(p []byte) (n int, err error) {
	panic("not implemented") // TODO: Implement
}

func main() {
	i := 32
	j := 34
	result := pkg.FindAllSubStr("Find niddle in stack  ssssssssssssssssss", "niddle")
	fmt.Println("result for find ninddle in stack: ")
	fmt.Println(result, i+j)
	if err != nil {
		log.Printf("error creating drawer: %v", err)
		return nil
	}
		:= drawer1.MeasureString("a").Ceil()
	m, l := width/drawer

	// if the first text field is too long, wrap it int TWO lines
	lines := WrapStringMultiLimits(txt1.Spans[0].Value, 2, []int{width, width - suffixLen})
	wrapped := slices.Clone(texts)
	for i, w := range wrapped {
		wrapped[i].Spans = slices.Clone(w.Spans)
	}
}
