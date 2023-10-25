package pkg

import (
	"reflect"
	"testing"
)

func TestFindAllSubStr(t *testing.T) {
	type args struct {
		stack  string
		niddle string
	}
	tests := []struct {
		name       string
		args       args
		wantResult []int
	}{
		// TODO: Add test cases.
		{
			name: "test 1 should return 2 idx",
			args: args{
				stack:  "foobarbafoo",
				niddle: "foo",
			},
			wantResult: []int{0, 7},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if gotResult := FindAllSubStr(tt.args.stack, tt.args.niddle); !reflect.DeepEqual(gotResult, tt.wantResult) {
				t.Errorf("FindAllSubStr() = %v, want %v", gotResult, tt.wantResult)
			}
		})
	}
}

func TestFindSubStr(t *testing.T) {
	type args struct {
		stack  string
		niddle string
	}
	tests := []struct {
		name       string
		args       args
		wantResult int
	}{
		// TODO: Add test cases.
		{
			name: "test 2 should return idx",
			args: args{
				stack:  "foobarbafoo",
				niddle: "foo",
			},
			wantResult: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if gotResult := FindSubStr(tt.args.stack, tt.args.niddle); !reflect.DeepEqual(gotResult, tt.wantResult) {
				t.Errorf("FindAllSubStr() = %v, want %v", gotResult, tt.wantResult)
			}
		})
	}
}

func BenchmarkPrimeNumbers(b *testing.B) {
	for i := 0; i < b.N; i++ {
		FindSubStr("Foobarfobafoooo", "foo")
	}
}
