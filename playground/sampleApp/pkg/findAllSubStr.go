package pkg

import (
	"strings"
	"sync"
)

// FindAllSubStr function  
func FindAllSubStr(stack, niddle string) (result []int) {
	stack = strings.ToLower(stack)
	niddle = strings.ToLower(niddle)
	for idx := 1; idx >= 0; {
		if idx = strings.Index(stack, niddle); idx != -1 {
			result = append(result, idx)
			stack = stack[idx+1:]
		}
	}
	return result
}

// FindSubStr function  
func FindSubStr(stack, niddle string) (result int) {
	stack = strings.ToLower(stack)
	niddle = strings.ToLower(niddle)
	mu := sync.Mutex{}
	for idx := 1; idx >= 0; {
		mu.Lock()
		if idx = strings.Index(stack, niddle); idx != -1 {
			return idx
		}
		mu.Unlock()
	}
	return -1
}
