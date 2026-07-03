# zeta
A tiny language made in Zig for learning purposes.

## Testing
Running the main file for debug printing in /src:
```
zig build run
```

Running tests:
```
zig build test --summary all
```
## Roadmap

### Current: Crafting Interpreters
- [ ] Chapter 7 — Evaluating expressions / statements
- [ ] Chapter 8 — Statements and state (variables)
- [ ] Chapter 9 — Control flow
- [ ] Chapter 10 — Functions

### Future: Signature Features

#### Unit / Tagged Number Types (core identity)
Numbers carry units, operations derive new units, mismatched units are type errors.
Touches every layer: lexer (parsing `100m`), types (tracking through operations), eval (conversion).
```
let distance = 100m
let time = 9.58s
let speed = distance / time    // -> 10.44 m/s (derived unit)
```

Internally all values stored in SI base units (m, s, kg, A, K). SI prefixes supported automatically (`5km` = 5000m). Conversion via `as` keyword:
```
unit mile = 1609.34m
let marathon = 42.195km
marathon as mile    // -> 26.2 miles
```

#### String Interpolation (f-strings)
Use a prefix like Python's `f"..."` rather than making all strings interpolated.
Keeps regular strings simple and fast — no scanning for `{}`.
```
let name = "Bolt"
let speed = 10.44
f"Runner {name} averaged {speed} m/s"   // interpolated
"just a regular string"                  // no interpolation
```

#### Range Literals
First-class range values, usable in for-loops and slicing.
```
1..10      // exclusive end
1..=10     // inclusive end
```
