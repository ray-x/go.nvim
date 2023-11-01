package coverage

import "testing"

func Test_branch(t *testing.T) {
	type args struct {
		a int
		b int
	}

	tests := []struct {
		name string
		args args
		want int
	}{
		// TODO: Add test cases.
		{
			name: "a10",
			args: args{a: 10},
			want: 10,
		},
		{
			name: "b10",
			args: args{b: 10},
			want: 20,
		},
		{
			name: "b10",
			args: args{},
			want: 0,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := branch(tt.args.a, tt.args.b); got != tt.want {
				t.Errorf("branch() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestBranch(t *testing.T) {
	type args struct {
		a int
		b int
	}

	tests := []struct {
		name string
		args args
		want int
	}{
		// TODO: Add test cases.
		{
			name: "a10",
			args: args{a: 10},
			want: 10,
		},
		{
			name: "b10",
			args: args{b: 10},
			want: 20,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := branch(tt.args.a, tt.args.b); got != tt.want {
				t.Errorf("branch() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestBranchSubTest(t *testing.T) {
	t.Run("a11", func(t *testing.T) {
		if got := branch(10, 0); got != 10 {
			t.Errorf("branch() = %v, want %v", got, 10)
		}
	})

	t.Run("b11", func(t *testing.T) {
		if got := branch(10, 0); got != 10 {
			t.Errorf("branch() = %v, want %v", got, 10)
		}
	})
}
