-- Shared prompt building blocks for Go code review (used by ai.lua and mcp/review.lua)

local M = {}

-- stylua: ignore start

M.audit_categories = [[
# Audit Categories

1. Code Organization: Misaligned project structure, init function abuse, or getter/setter overkill.
2. Data Types: Octal literals, integer overflows, floating-point inaccuracies, and slice/map header confusion.
3. Control Structures: Range loop pointer copies, using break in switch inside for loops, and map iteration non-determinism.
4. String Handling: Inefficient concatenation, len() vs. rune count, and substring memory leaks.
5. Functions & Methods: Pointer vs. value receivers, named result parameters, and returning nil interfaces.
6. Error Management: Panic/recover abuse, ignoring errors, and failing to wrap errors with %w.
7. Concurrency: Goroutine leaks, context misuse, data races, and sync vs. channel trade-offs.
8. Standard Library: http body closing, json marshaling pitfalls, and time.After leaks.
9. Testing: Table-driven test errors, race conditions in tests, and external dependency mocking.
10. Optimizations: CPU cache misalignment, false sharing, and stack vs. heap escape analysis.]]

M.review_dimensions = [[
# Go-Specific Review Dimensions

## Formatting & Naming (Effective Go / Google Style)
- Indentation/Formatting: Check for non-standard layouts (assume gofmt standards).
- Naming: Enforce short, pithy names for local variables (e.g., r for reader) and MixedCaps/Exported naming conventions.
- Interface Names: Ensure one-method interfaces end in an "er" suffix (e.g., Reader, Writer).
- Function/Method Naming: Avoid repeating package name (e.g., yamlconfig.Parse not yamlconfig.ParseYAMLConfig), receiver type, parameter names, or return types in the function name.
- No Get Prefix: Functions returning values should use noun-like names without "Get" prefix (e.g., JobName not GetJobName). Functions doing work should use verb-like names.
- Util Packages: Flag packages named "util", "helper", "common" — names should describe what the package provides.

## Initialization & Control (The "Go Way")
- Redeclaring vs. Reassigning: Identify where := is used correctly vs. where it creates shadowing bugs. Flag shadowing of variables in inner scopes (especially context, error) that silently creates new variables instead of updating the outer one.
- Do not shadow standard package names (e.g., using "url" as a variable name blocks net/url).
- The Switch Power: Look for complex if-else chains that should be simplified into Go's powerful switch (which handles multiple expressions and comparisons).
- Allocation: Differentiate between new (zeroed memory pointer) and make (initialized slice/map/chan).
- Prefer := for non-zero initialization, var for zero-value declarations.
- Signal Boosting: Flag easy-to-miss "err == nil" checks (positive error checks) — these should have a clarifying comment.

## Data Integrity & Memory (100 Go Mistakes)
- Slice/Map Safety: Check for sub-slice memory leaks and map capacity issues.
- Conversions: Ensure string-to-slice conversions are necessary and efficient.
- Backing Arrays: Flag cases where multiple slices share a backing array unintentionally.
- Size Hints: For performance-sensitive code, check if make() should have capacity hints for slices/maps when the size is known.
- Channel Direction: Ensure channel parameters specify direction (<-chan or chan<-) where possible.
- Map Initialization: Flag writes to nil maps (maps must be initialized with make before mutation, though reads are safe).

## Concurrency & Errors
- Communication: "Do not communicate by sharing memory; instead, share memory by communicating." Flag excessive Mutex use where Channels would be cleaner.
- Only sender can close a channel: Flag cases where multiple goroutines might close the same channel, which can cause panics.
- Error Handling: Check for the "Happy Path" (return early on errors to keep the successful logic left-aligned).
- Error Structure: Flag string-matching on error messages — use sentinel errors, errors.Is, or errors.As instead.
- Error Wrapping: Ensure %w is used (not %v) when callers need to inspect wrapped errors. Place %w at the end of the format string. Avoid redundant annotations (e.g., "failed: %v" adds nothing — just return err). Do not duplicate information the underlying error already provides.
- Panic/Recover: Ensure panic is only used for truly unrecoverable setup errors or API misuse, not for flow control. Panics must never escape package boundaries in libraries — use deferred recover at public API boundaries.
- Do not call log.Fatal or t.Fatal from goroutines other than the main test goroutine.
- Handle error cases first (left-aligned), then the successful path. Avoid deep nesting of if statements for the happy path. Reduce `if err != nil` nesting by returning early.
- Errors should only be handled once — avoid patterns where errors are checked, annotated, and returned in multiple layers.
- Use traceID or context values for cross-cutting concerns instead of passing through multiple layers of error annotations.

## Documentation & API Design (Google Style)
- Context conventions: Do not restate that cancelling ctx stops the function (it is implied). Document only non-obvious context behavior.
- Cleanup: Exported constructors/functions that acquire resources must document how to release them (e.g., "Call Stop to release resources when done").
- Concurrency safety: Document non-obvious concurrency properties. Read-only operations are assumed safe; mutating operations are assumed unsafe. Document exceptions.
- Error documentation: Document significant sentinel errors and error types returned by functions, including whether they are pointer receivers.
- Function argument lists: Flag functions with too many parameters. Recommend option structs or variadic options pattern for complex configuration.

## Testing (Google Style)
- Leave testing to the Test function: Flag assertion helper libraries — prefer returning errors or using cmp.Diff with clear failure messages in the Test function itself.
- Table-driven tests: Use field names in struct literals. Keep setup scoped to tests that need it (no global init for test data).
- t.Fatal usage: Use t.Fatal only for setup failures. In table-driven subtests, use t.Fatal inside t.Run; outside subtests, use t.Error + continue.
- Do not call t.Fatal from separate goroutines — use t.Error and return instead.
- Test doubles: Follow naming conventions (package suffixed with "test", types named by behavior like AlwaysCharges).
- Mocking: Prefer interface-based design for testability. For external dependencies, use in-memory implementations or test servers instead of complex mocking frameworks.
- Logging: Use t.Log for test logs, not global loggers. Test logs are only shown on failure or with verbose flag.
- Avoid shared state between tests. Each test should be independent and repeatable.

## Global State & Dependencies
- Flag package-level mutable state (global vars, registries, singletons). Prefer instance-based APIs with explicit dependency passing.
- Flag service locator patterns and thick-client singletons.

## String Handling (Google Style)
- Prefer "+" for simple concatenation, fmt.Sprintf for formatting, strings.Builder for piecemeal construction.
- Use backticks for constant multi-line strings.]]

M.output_critique_format = [[
# Output Instructions

For every critique, provide:
1. The Violation (e.g., "Non-idiomatic naming" or "Slice memory leak").
2. The Principle: Cite if it is an [Effective Go] rule, a [100 Go Mistakes] pitfall, or a [Google Style] convention.
3. A brief refactored code suggestion where applicable.]]

-- stylua: ignore end

--- Build the full review guidelines block (audit + dimensions + output instructions)
function M.review_guidelines()
  return M.audit_categories .. '\n' .. M.review_dimensions .. '\n' .. M.output_critique_format
end

return M
