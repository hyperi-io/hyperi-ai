---
paths:
  - "**/*.cpp"
  - "**/*.hpp"
  - "**/*.cc"
  - "**/*.h"
  - "**/*.cxx"
detect_markers:
  - "file:CMakeLists.txt"
  - "deep_file:CMakeLists.txt"
  - "deep_glob:*.cpp"
  - "deep_glob:*.hpp"
source: languages/CPP.md
---

<!-- override: manual -->
## Target: C++20 (C++23 where clang supports)

## Build & Tools
```bash
cmake -B build -GNinja -DCMAKE_BUILD_TYPE=RelWithDebInfo && ninja -C build
./build/unit_tests --gtest_filter='*JSON*'
clang-tidy src/*.cpp -- -std=c++20
clang-format -i src/*.cpp src/*.h
cmake -B build-asan -DSANITIZE=address -GNinja && ninja -C build-asan
```

## Zero-Copy by Default
- Use `std::string_view` over `const std::string&` for read-only string params
- Use `std::span<const T>` over `const std::vector<T>&` for read-only array params
- Never pass `std::vector<T>` by value in hot paths
- Use arena allocation for batch processing; reset arena between batches

## SIMD
- Prefer Highway or xsimd over raw intrinsics for portability
- Use `alignas(32)` for SIMD buffers; use `std::aligned_alloc` for dynamic
- Always handle tail elements with a scalar loop after SIMD loop
- Use aligned loads (`_mm256_load_ps`) over unaligned (`_mm256_loadu_ps`) when possible

## Memory Management
- RAII everywhere — wrap C resources in RAII classes (non-copyable, movable)
- `std::unique_ptr<T>` for single owner (default), `std::shared_ptr<T>` for shared ownership
- Raw pointer/reference = non-owning borrowed access only
- `std::array<T, N>` for small fixed-size stack allocations
- Never use `new`/`delete` directly:
  - ❌ `char* buf = new char[size]; delete[] buf;`
  - ✅ `auto buf = std::make_unique<char[]>(size);`

## Error Handling
- Use `std::optional` for expected lookup failures
- Use `std::expected` (C++23) or equivalent for recoverable errors with context
- Catch exceptions at boundaries (connection handlers, entry points), not everywhere
- Never throw from destructors — log and swallow in `noexcept` destructors

## Naming (ClickHouse-Compatible)
- Variables/members: `snake_case` — `max_block_size`
- Functions/methods: `camelCase` — `getName()`
- Classes/structs: `CamelCase` — `DataTypeString`
- Constants/macros: `UPPER_SNAKE` — `MAX_BLOCK_SIZE`
- Abbreviations: lowercase in variables (`mysql_connection`), preserved in classes (`HTTPClient`)
- Constructor params: underscore suffix (`input_`) to distinguish from members

## Formatting
- 4-space indent, Allman braces (own line)
- Single-statement functions may be one line: `size_t getSize() const { return size; }`
- Pointer/reference: spaces both sides — `const char * pos`, `const Block & block`
- Wrap at ~120 chars; operators on new line with indent
- `const` BEFORE type: `const std::string & name` not `std::string const &`
- Use `.clang-format` with `BasedOnStyle: LLVM`, `IndentWidth: 4`, `BreakBeforeBraces: Allman`, `PointerAlignment: Middle`

## Concurrency
- Use `std::lock_guard`/`std::unique_lock` with mutex — never manual lock/unlock
- Use `std::shared_mutex` with `std::shared_lock` for read-heavy workloads
- Use `std::atomic` with explicit memory ordering for counters/flags
- Use thread pools — never spawn raw `std::thread` in production code
- Use `std::call_once` for one-time init, not hand-rolled double-checked locking

## Modern C++ Features
- Use concepts to constrain templates
- Use ranges (`std::views::filter`, `std::views::transform`) for data pipelines
- Use structured bindings: `auto [iter, inserted] = map.insert({key, value});`
- Use `constexpr` for compile-time computation and lookup tables

## Performance Patterns
- Prefer Structure of Arrays (SoA) over Array of Structures (AoS) for cache locality
- Pre-allocate buffers in classes; `clear()` and reuse instead of reallocating
- Use `likely()`/`unlikely()` (`__builtin_expect`) for branch hints in hot paths
- Reserve string capacity before loop concatenation — `+=` not `+` in loops

## Common Pitfalls
- Never return `std::string_view` from a function that creates the string locally
- Never assign temporary to `string_view`: ❌ `std::string_view v = std::string("temp");`
- Use `std::erase_if` or proper iterator handling — never erase during range-for
- Never use moved-from objects: ❌ `process(std::move(data)); data->value = 10;`
- Move into containers: `cache[std::move(key)] = std::move(value);`
- Always declare `virtual ~Base() = default;` for polymorphic base classes

## Advanced Patterns
- COW smart pointers for large shared immutable objects (columns, blocks)
- PODArray with SIMD right-padding (64 bytes) for safe overread at boundaries
- Arena allocator with hybrid growth (exponential → linear above 128MB)
- ArenaWithFreeLists for reuse of freed memory within arena
- Stack-first allocator (`AllocatorWithStackMemory`) for small aggregate states
- `assert_cast<To>(from)`: `dynamic_cast` in debug, `static_cast` in release
- `SCOPE_EXIT_SAFE(...)` for exception-safe RAII cleanup
- Multi-target SIMD: compile for SSE4.2/AVX2/AVX512, dispatch at runtime via CPU detection

## Testing
- GoogleTest with fixtures (`::testing::Test`), parameterized tests (`TestWithParam`)
- Test files: `src/Module/tests/gtest_module.cpp`
- Name tests: `TEST_F(ParserTest, ParsesValidJSON)`
- Run all sanitizer builds (ASan, TSan, UBSan) in CI

## AI: Do NOT Generate
- `new`/`delete` — use smart pointers
- C-style casts `(int)x` — use `static_cast<int>(x)`
- `NULL` or `0` — use `nullptr`
- C-style arrays in interfaces — use `std::span`
- `std::endl` — use `'\n'`
- Catch by value — catch by `const &`
- `std::bind` — use lambdas
- Non-atomic shared mutable state without synchronization
- `#include <format>` without checking support — use `fmt` library as fallback
- `std::string::contains()`, `std::ranges::to<>()` without confirming C++23 availability

## Compiler Warnings
```cmake
-Wall -Wextra -Werror -Wpedantic -Wshadow -Wcast-align -Wconversion
-Wsign-conversion -Wnull-dereference -Wdouble-promotion -Wformat=2
-Wold-style-cast -Woverloaded-virtual -Wnon-virtual-dtor
```

## clang-tidy Checks
- Enable: `bugprone-*`, `clang-analyzer-*`, `cppcoreguidelines-*`, `modernize-*`, `performance-*`, `readability-*`
- Disable: `modernize-use-trailing-return-type`, `readability-identifier-naming`, `*-magic-numbers`
- Set `readability-function-cognitive-complexity.Threshold: 25`
```
