---
name: cpp-standards
description: C++ coding standards for high-performance data systems. Use when writing C++ code, reviewing C++, or working on systems like ClickHouse. Covers memory safety, zero-copy patterns, SIMD, concurrency, and performance optimisation.
rule_paths:
  - "**/*.cpp"
  - "**/*.hpp"
  - "**/*.cc"
  - "**/*.cxx"
  - "**/*.h"
detect_markers:
  - "file:CMakeLists.txt"
  - "deep_file:CMakeLists.txt"
  - "deep_glob:*.cpp"
  - "deep_glob:*.hpp"
paths:
  - "**/*.cpp"
  - "**/*.hpp"
  - "**/*.cc"
  - "**/*.h"
  - "**/*.cxx"
---

# C++ Standards for HyperI Projects

**C++ coding standards for high-performance data processing, database internals, and systems programming**

**Target: C++20** (C++23 features where supported by clang)

---

## Quick Reference

```bash
# Build
cmake -B build -GNinja -DCMAKE_BUILD_TYPE=RelWithDebInfo
ninja -C build

# Test
./build/unit_tests --gtest_filter='*JSON*'

# Lint
clang-tidy src/*.cpp -- -std=c++20

# Format
clang-format -i src/*.cpp src/*.h

# Sanitizers
cmake -B build-asan -DSANITIZE=address -GNinja && ninja -C build-asan
cmake -B build-tsan -DSANITIZE=thread -GNinja && ninja -C build-tsan
cmake -B build-ubsan -DSANITIZE=undefined -GNinja && ninja -C build-ubsan
```

---

## Core Principles for High-Volume Data Processing

### Zero-Copy by Default

Minimise memory copies in hot paths. Every allocation and copy is a performance tax.

```cpp
// ✅ Good - zero-copy with string_view
void parseField(std::string_view data) {
    // No allocation, just a view into existing memory
    auto field = data.substr(0, data.find(','));
    process(field);
}

// ❌ Bad - unnecessary copy
void parseField(const std::string & data) {
    std::string field = data.substr(0, data.find(','));  // Allocates!
    process(field);
}

// ✅ Good - span for array views
void processBlock(std::span<const uint64_t> values) {
    for (auto v : values) { /* ... */ }
}

// ❌ Bad - copies entire vector
void processBlock(std::vector<uint64_t> values) {  // Copies on call!
    for (auto v : values) { /* ... */ }
}
```

### Prefer Views Over Copies

| Type | Zero-Copy Alternative |
|------|----------------------|
| `std::string` | `std::string_view` |
| `std::vector<T>` | `std::span<T>` or `std::span<const T>` |
| `const char *` + length | `std::string_view` |
| Array slice | `std::span<T>` |

### Arena Allocation for Batch Processing

```cpp
// ✅ Good - arena allocator for batch operations
class Arena {
    std::vector<char> buffer;
    size_t offset = 0;

public:
    explicit Arena(size_t capacity) : buffer(capacity) {}

    char * allocate(size_t size) {
        if (offset + size > buffer.size())
            throw std::bad_alloc();
        char * ptr = buffer.data() + offset;
        offset += size;
        return ptr;
    }

    void reset() { offset = 0; }  // Instant "free" of all allocations
};

// Process batch, then reset arena for next batch
void processBatch(Arena & arena, std::span<const Record> records) {
    for (const auto & record : records) {
        char * buf = arena.allocate(record.size());
        // ... process ...
    }
    arena.reset();  // Single operation frees all
}
```

---

## SIMD Best Practices

### Use Abstraction Libraries

Prefer portable SIMD libraries over raw intrinsics for maintainability:

- **Highway** (Google) - Recommended for portability
- **xsimd** - Header-only, widely used
- **simdjson** - JSON-specific SIMD parsing

```cpp
// ✅ Good - Highway for portable SIMD
#include <hwy/highway.h>
namespace hn = hwy::HWY_NAMESPACE;

void sumArray(const float * HWY_RESTRICT input, float * HWY_RESTRICT output, size_t count) {
    const hn::ScalableTag<float> d;
    for (size_t i = 0; i < count; i += hn::Lanes(d)) {
        auto v = hn::Load(d, input + i);
        hn::Store(v, d, output + i);
    }
}
```

### Raw Intrinsics Guidelines

When raw intrinsics are necessary:

```cpp
// ✅ Good - aligned loads, process in registers
#include <immintrin.h>

void processAligned(const float * data, size_t count) {
    for (size_t i = 0; i < count; i += 8) {
        __m256 v = _mm256_load_ps(data + i);  // Aligned load
        v = _mm256_mul_ps(v, v);               // Process in register
        _mm256_store_ps(output + i, v);        // Store result
    }
}

// ❌ Bad - unaligned access, memory operations in loop
void processUnaligned(const float * data, size_t count) {
    for (size_t i = 0; i < count; ++i) {
        __m256 v = _mm256_loadu_ps(data + i);  // Unaligned, expensive
        // Multiple memory accesses per iteration
    }
}
```

### Memory Alignment

```cpp
// ✅ Good - aligned allocation
alignas(32) float buffer[1024];

// Or dynamic allocation
float * aligned_buffer = static_cast<float*>(
    std::aligned_alloc(32, 1024 * sizeof(float))
);

// ✅ Good - handle tail elements
void processSIMD(const float * data, size_t count) {
    constexpr size_t LANES = 8;  // AVX: 256 bits / 32 bits
    size_t i = 0;

    // SIMD loop for aligned portion
    for (; i + LANES <= count; i += LANES) {
        __m256 v = _mm256_load_ps(data + i);
        // ... process ...
    }

    // Scalar loop for remainder
    for (; i < count; ++i) {
        // ... scalar processing ...
    }
}
```

---

## Memory Management

### RAII Everywhere

```cpp
// ✅ Good - RAII with unique_ptr
auto buffer = std::make_unique<char[]>(size);
// Automatically freed when out of scope

// ✅ Good - RAII wrapper for C resources
class FileHandle {
    FILE * file;
public:
    explicit FileHandle(const char * path) : file(fopen(path, "r")) {
        if (!file) throw std::runtime_error("Failed to open file");
    }
    ~FileHandle() { if (file) fclose(file); }

    // Non-copyable, movable
    FileHandle(const FileHandle &) = delete;
    FileHandle & operator=(const FileHandle &) = delete;
    FileHandle(FileHandle && other) noexcept : file(other.file) { other.file = nullptr; }
    FileHandle & operator=(FileHandle && other) noexcept {
        if (this != &other) {
            if (file) fclose(file);
            file = other.file;
            other.file = nullptr;
        }
        return *this;
    }

    FILE * get() const { return file; }
};
```

### Smart Pointer Guidelines

| Ownership | Type | Use Case |
|-----------|------|----------|
| Unique | `std::unique_ptr<T>` | Single owner, most common |
| Shared | `std::shared_ptr<T>` | Multiple owners, reference counted |
| Non-owning | `T *` or `T &` | Borrowed access, no lifetime management |
| Weak reference | `std::weak_ptr<T>` | Break cycles, optional access to shared |

```cpp
// ✅ Good - unique_ptr for exclusive ownership
auto node = std::make_unique<Node>(data);
tree.insert(std::move(node));

// ✅ Good - shared_ptr for shared ownership (e.g., cached types)
auto type = std::make_shared<DataType>(specs);
cache.insert(type);  // Cache holds reference
column.setType(type);  // Column also holds reference

// ✅ Good - raw pointer for non-owning access
void process(const Node * node) {  // Borrowed, not owned
    if (node) { /* ... */ }
}

// ❌ Bad - manual new/delete
Node * node = new Node(data);  // Who owns this? When freed?
```

### Avoid Manual Memory Management

```cpp
// ❌ Bad - manual delete
void process() {
    char * buffer = new char[size];
    // ... if exception thrown, buffer leaks ...
    delete[] buffer;
}

// ✅ Good - automatic cleanup
void process() {
    auto buffer = std::make_unique<char[]>(size);
    // ... exception safe, auto-freed ...
}

// ✅ Good - stack allocation for small objects
void process() {
    std::array<char, 256> buffer;  // Stack allocated, fast
    // ...
}
```

---

## Error Handling

### Use Exceptions for Errors

```cpp
// ✅ Good - throw on error with context
DataTypePtr parseType(std::string_view type_str) {
    if (type_str.empty())
        throw Exception(ErrorCodes::BAD_ARGUMENTS, "Type string cannot be empty");

    auto result = tryParse(type_str);
    if (!result)
        throw Exception(ErrorCodes::CANNOT_PARSE_TYPE,
            "Cannot parse type: '{}'", type_str);

    return result;
}

// ✅ Good - use std::optional for expected failures
std::optional<int64_t> tryParseInt(std::string_view str) {
    int64_t value;
    auto [ptr, ec] = std::from_chars(str.begin(), str.end(), value);
    if (ec != std::errc{})
        return std::nullopt;
    return value;
}
```

### Exception Guidelines

```cpp
// ✅ Good - catch at boundaries, not everywhere
void handleConnection(Connection & conn) {
    try {
        while (auto query = conn.readQuery()) {
            auto result = executeQuery(*query);  // May throw
            conn.writeResult(result);
        }
    } catch (const Exception & e) {
        conn.writeError(e);
        LOG_ERROR(log, "Query failed: {}", e.what());
    }
}

// ❌ Bad - exception in destructor (undefined behaviour)
class BadResource {
    ~BadResource() {
        if (!cleanup())
            throw std::runtime_error("Cleanup failed");  // NEVER DO THIS
    }
};

// ✅ Good - log errors in destructor, don't throw
class GoodResource {
    ~GoodResource() noexcept {
        try {
            cleanup();
        } catch (const std::exception & e) {
            LOG_ERROR(log, "Cleanup failed: {}", e.what());
        }
    }
};
```

### std::expected (C++23)

```cpp
// ✅ Good - std::expected for recoverable errors
std::expected<Config, std::string> loadConfig(const std::string & path) {
    auto content = readFile(path);
    if (!content)
        return std::unexpected("Failed to read file: " + path);

    auto parsed = parseYAML(*content);
    if (!parsed)
        return std::unexpected("Invalid YAML in: " + path);

    return Config{*parsed};
}

// Usage with monadic operations
auto result = loadConfig("config.yaml")
    .and_then(validateConfig)
    .transform(applyDefaults)
    .or_else([](const std::string & err) {
        LOG_WARNING(log, "Using defaults: {}", err);
        return Config::defaults();
    });
```

---

## Naming Conventions

### ClickHouse-Compatible Style

| Element | Convention | Example |
|---------|------------|---------|
| Variables, members | snake_case | `max_block_size`, `column_name` |
| Functions, methods | camelCase | `getName()`, `parseValue()` |
| Classes, structs | CamelCase | `DataTypeString`, `ColumnVector` |
| Constants, macros | UPPER_SNAKE | `MAX_BLOCK_SIZE`, `DEFAULT_PORT` |
| Template params | `T`, or descriptive | `typename T`, `typename TValue` |
| Namespaces | lowercase | `DB`, `detail` |

### Abbreviation Rules

```cpp
// Variables: lowercase abbreviations
std::string mysql_connection;  // ✅
std::string mySQL_connection;  // ❌

// Classes: preserve abbreviation case
class MySQLConnection {};  // ✅
class MysqlConnection {};  // ❌ (inconsistent)

class HTTPClient {};       // ✅
class HttpClient {};       // ❌
```

### Member Variables

```cpp
class Parser {
private:
    std::string_view input;      // No prefix needed
    size_t position = 0;
    bool strict_mode = false;

public:
    // Constructor parameters match members with underscore suffix
    explicit Parser(std::string_view input_, bool strict_mode_ = false)
        : input(input_)
        , strict_mode(strict_mode_)
    {}
};
```

---

## Formatting

### Indentation and Braces

```cpp
// 4 spaces, braces on own lines
void processData(const Block & block)
{
    if (block.empty())
    {
        return;
    }

    for (const auto & column : block)
    {
        processColumn(column);
    }
}

// Single-statement functions can be one line
size_t getSize() const { return size; }

// Pointer/reference: spaces on both sides
const char * pos = buffer.data();
const Block & block = getBlock();
```

### Line Length and Wrapping

```cpp
// Wrap at ~120-140 characters
// Operators on new line with increased indent

auto result = firstCondition
    && secondCondition
    && thirdCondition;

auto value = computeBaseValue()
    + adjustment
    * multiplier;

// Multi-line function calls: align arguments or 4-space indent
auto result = veryLongFunctionName(
    firstArgument,
    secondArgument,
    thirdArgument);

// Or with trailing comma for cleaner diffs
auto result = createObject(
    .name = "test",
    .value = 42,
    .enabled = true,
);
```

### const Placement

```cpp
// const BEFORE type (ClickHouse style)
const char * pos = data;           // ✅
char const * pos = data;           // ❌

const std::string & name = getName();  // ✅
std::string const & name = getName();  // ❌
```

---

## Concurrency

### Thread Safety Patterns

```cpp
// ✅ Good - mutex with lock_guard
class ThreadSafeCache {
    mutable std::mutex mutex;
    std::unordered_map<std::string, Value> cache;

public:
    void insert(const std::string & key, Value value) {
        std::lock_guard lock(mutex);
        cache[key] = std::move(value);
    }

    std::optional<Value> get(const std::string & key) const {
        std::lock_guard lock(mutex);
        auto it = cache.find(key);
        if (it == cache.end())
            return std::nullopt;
        return it->second;
    }
};

// ✅ Good - read-write lock for read-heavy workloads
class ReadHeavyCache {
    mutable std::shared_mutex mutex;
    std::unordered_map<std::string, Value> cache;

public:
    std::optional<Value> get(const std::string & key) const {
        std::shared_lock lock(mutex);  // Multiple readers allowed
        auto it = cache.find(key);
        return it != cache.end() ? std::optional{it->second} : std::nullopt;
    }

    void insert(const std::string & key, Value value) {
        std::unique_lock lock(mutex);  // Exclusive access
        cache[key] = std::move(value);
    }
};
```

### Atomic Operations

```cpp
// ✅ Good - atomics for simple counters/flags
class Counter {
    std::atomic<uint64_t> count{0};

public:
    void increment() { count.fetch_add(1, std::memory_order_relaxed); }
    uint64_t get() const { return count.load(std::memory_order_relaxed); }
};

// ✅ Good - atomic flag for one-time initialisation
class LazyInit {
    std::atomic<bool> initialised{false};
    std::mutex init_mutex;
    Value value;

public:
    const Value & get() {
        if (!initialised.load(std::memory_order_acquire)) {
            std::lock_guard lock(init_mutex);
            if (!initialised.load(std::memory_order_relaxed)) {
                value = computeExpensiveValue();
                initialised.store(true, std::memory_order_release);
            }
        }
        return value;
    }
};
```

### Thread Pool Pattern

```cpp
// ✅ Good - submit work to thread pool, don't spawn raw threads
void processInParallel(std::span<const Task> tasks) {
    ThreadPool pool(std::thread::hardware_concurrency());

    for (const auto & task : tasks) {
        pool.submit([&task]() {
            processTask(task);
        });
    }

    pool.wait();  // Wait for all tasks to complete
}

// ❌ Bad - spawning threads directly
void processInParallel(std::span<const Task> tasks) {
    std::vector<std::thread> threads;
    for (const auto & task : tasks) {
        threads.emplace_back([&task]() { processTask(task); });
    }
    for (auto & t : threads) t.join();
}
```

---

## Testing

### GoogleTest Patterns

```cpp
#include <gtest/gtest.h>

// Test fixture for shared setup
class ParserTest : public ::testing::Test {
protected:
    void SetUp() override {
        parser = std::make_unique<Parser>();
    }

    std::unique_ptr<Parser> parser;
};

// Test naming: Test_Scenario or Test_Scenario_ExpectedResult
TEST_F(ParserTest, ParsesValidJSON) {
    auto result = parser->parse(R"({"key": "value"})");
    ASSERT_TRUE(result.has_value());
    EXPECT_EQ(result->get("key"), "value");
}

TEST_F(ParserTest, ReturnsErrorForInvalidJSON) {
    auto result = parser->parse("{invalid}");
    EXPECT_FALSE(result.has_value());
}

// Parameterised tests for multiple inputs
class TypeParserTest : public ::testing::TestWithParam<std::pair<std::string, DataTypePtr>> {};

TEST_P(TypeParserTest, ParsesTypeCorrectly) {
    auto [input, expected] = GetParam();
    auto result = parseDataType(input);
    EXPECT_EQ(result->getName(), expected->getName());
}

INSTANTIATE_TEST_SUITE_P(CommonTypes, TypeParserTest, ::testing::Values(
    std::make_pair("String", std::make_shared<DataTypeString>()),
    std::make_pair("UInt64", std::make_shared<DataTypeUInt64>()),
    std::make_pair("Float64", std::make_shared<DataTypeFloat64>())
));
```

### Test Organisation

```text
src/
├── Module/
│   ├── Parser.cpp
│   ├── Parser.h
│   └── tests/
│       ├── gtest_parser.cpp
│       └── gtest_parser_edge_cases.cpp
```

---

## Sanitizers

### Build Configurations

```cmake
# CMakeLists.txt
option(SANITIZE "Enable sanitizer (address, thread, undefined, memory)" "")

if(SANITIZE STREQUAL "address")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fsanitize=address -fno-omit-frame-pointer")
elseif(SANITIZE STREQUAL "thread")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fsanitize=thread")
elseif(SANITIZE STREQUAL "undefined")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fsanitize=undefined")
elseif(SANITIZE STREQUAL "memory")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fsanitize=memory")
endif()
```

### CI Integration

```yaml
# .github/workflows/sanitizers.yml
jobs:
  asan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build with ASan
        run: |
          cmake -B build -DSANITIZE=address
          cmake --build build
      - name: Test with ASan
        run: ./build/unit_tests

  tsan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build with TSan
        run: |
          cmake -B build -DSANITIZE=thread
          cmake --build build
      - name: Test with TSan
        run: ./build/unit_tests
```

### Sanitizer Suppression

```cpp
// Suppress false positives with attributes
__attribute__((no_sanitize("address")))
void knownSafeButFlaggedFunction() {
    // ... code that triggers false positive ...
}

// Or use suppression files
// Create asan_suppressions.txt:
// interceptor_via_fun:knownSafeFunction
// leak:ThirdPartyLibrary

// Run with: ASAN_OPTIONS=suppressions=asan_suppressions.txt ./program
```

---

## Static Analysis

### clang-tidy Configuration

```yaml
# .clang-tidy
Checks: >
  -*,
  bugprone-*,
  clang-analyzer-*,
  cppcoreguidelines-*,
  modernize-*,
  performance-*,
  readability-*,
  -modernize-use-trailing-return-type,
  -readability-identifier-naming,
  -cppcoreguidelines-avoid-magic-numbers,
  -readability-magic-numbers

WarningsAsErrors: '*'

CheckOptions:
  - key: performance-unnecessary-value-param.AllowedTypes
    value: 'shared_ptr;unique_ptr'
  - key: readability-function-cognitive-complexity.Threshold
    value: 25
```

### Compiler Warnings

```cmake
# Aggressive warning flags (ClickHouse style)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wextra -Werror")

# Additional useful warnings
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} \
    -Wcast-qual \
    -Wconversion \
    -Wdouble-promotion \
    -Wformat=2 \
    -Wnull-dereference \
    -Wold-style-cast \
    -Wshadow \
    -Wsign-conversion \
    -Wunused")
```

---

## Modern C++ Features

### Concepts (C++20)

```cpp
// ✅ Good - constrain templates with concepts
template<typename T>
concept Numeric = std::integral<T> || std::floating_point<T>;

template<Numeric T>
T sum(std::span<const T> values) {
    return std::accumulate(values.begin(), values.end(), T{0});
}

// Custom concepts for domain types
template<typename T>
concept DataType = requires(T t) {
    { t.getName() } -> std::convertible_to<std::string>;
    { t.getTypeId() } -> std::same_as<TypeId>;
};
```

### Ranges (C++20)

```cpp
#include <ranges>

// ✅ Good - ranges for data pipelines
auto result = values
    | std::views::filter([](int v) { return v > 0; })
    | std::views::transform([](int v) { return v * 2; })
    | std::views::take(10);

// Lazy evaluation - no intermediate allocations
for (auto v : result) {
    process(v);
}

// ✅ Good - ranges algorithms
auto it = std::ranges::find_if(items, [](const auto & item) {
    return item.isActive();
});
```

### Structured Bindings

```cpp
// ✅ Good - structured bindings for clarity
auto [iter, inserted] = map.insert({key, value});
if (!inserted) {
    LOG_WARNING(log, "Key already exists: {}", key);
}

// With ranges
for (const auto & [name, column] : columns) {
    processColumn(name, column);
}

// From functions returning tuples/pairs
auto [success, error_msg] = validateInput(input);
if (!success) {
    throw Exception(ErrorCodes::VALIDATION_FAILED, error_msg);
}
```

### constexpr and Compile-Time Computation

```cpp
// ✅ Good - compile-time computation
constexpr size_t BLOCK_SIZE = 1 << 16;  // 65536
constexpr size_t ALIGNMENT = 64;

constexpr size_t alignUp(size_t value, size_t alignment) {
    return (value + alignment - 1) & ~(alignment - 1);
}

// Compile-time lookup tables
constexpr std::array<uint8_t, 256> makeHexTable() {
    std::array<uint8_t, 256> table{};
    for (int i = '0'; i <= '9'; ++i) table[i] = i - '0';
    for (int i = 'a'; i <= 'f'; ++i) table[i] = 10 + i - 'a';
    for (int i = 'A'; i <= 'F'; ++i) table[i] = 10 + i - 'A';
    return table;
}

constexpr auto HEX_TABLE = makeHexTable();
```

---

## Performance Patterns

### Cache-Friendly Data Structures

```cpp
// ✅ Good - Structure of Arrays (SoA) for SIMD-friendly access
class ColumnVector {
    std::vector<int64_t> data;  // Contiguous, cache-friendly

public:
    void processAll() {
        // Sequential access pattern, prefetcher-friendly
        for (size_t i = 0; i < data.size(); ++i) {
            data[i] *= 2;
        }
    }
};

// ❌ Bad - Array of Structures (AoS) with pointer chasing
class ColumnPointers {
    std::vector<std::unique_ptr<Value>> data;  // Pointer chasing

public:
    void processAll() {
        for (auto & ptr : data) {
            ptr->value *= 2;  // Cache miss per element
        }
    }
};
```

### Avoid Allocations in Hot Paths

```cpp
class Parser {
    // Pre-allocated buffers
    std::string temp_buffer;
    std::vector<Token> tokens;

public:
    void parse(std::string_view input) {
        temp_buffer.clear();  // Reuse, don't reallocate
        tokens.clear();       // Reuse, don't reallocate

        // ... parse into existing buffers ...
    }
};
```

### Branch Prediction Hints

```cpp
// Hint for likely/unlikely branches
if (likely(ptr != nullptr)) {
    process(ptr);
}

if (unlikely(error_occurred)) {
    handleError();
}

// Define if not available
#ifndef likely
#define likely(x) __builtin_expect(!!(x), 1)
#define unlikely(x) __builtin_expect(!!(x), 0)
#endif
```

---

## Common Pitfalls

### Dangling References

```cpp
// ❌ Bad - dangling string_view
std::string_view getName() {
    std::string name = computeName();
    return name;  // DANGLING - name destroyed on return
}

// ✅ Good - return owned string
std::string getName() {
    std::string name = computeName();
    return name;  // Move semantics, efficient
}

// ✅ Good - string_view parameter referencing caller's data
void process(std::string_view name) {
    // Safe - caller owns the data
}
```

### Iterator Invalidation

```cpp
// ❌ Bad - modifying container while iterating
for (auto it = vec.begin(); it != vec.end(); ++it) {
    if (shouldRemove(*it)) {
        vec.erase(it);  // Invalidates iterator!
    }
}

// ✅ Good - use erase-remove idiom
std::erase_if(vec, [](const auto & item) {
    return shouldRemove(item);
});

// Or with explicit iterator handling
for (auto it = vec.begin(); it != vec.end(); ) {
    if (shouldRemove(*it)) {
        it = vec.erase(it);  // erase returns next valid iterator
    } else {
        ++it;
    }
}
```

### Move Semantics Mistakes

```cpp
// ❌ Bad - use after move
auto data = std::make_unique<Data>(values);
process(std::move(data));
data->value = 10;  // UNDEFINED - data was moved

// ❌ Bad - unnecessary copy
void addToCache(std::string key, Value value) {
    cache[key] = value;  // Copies both key and value
}

// ✅ Good - move into container
void addToCache(std::string key, Value value) {
    cache[std::move(key)] = std::move(value);
}
```

### Exception Safety Violations

```cpp
// ❌ Bad - not exception safe
void process() {
    lock();
    doWork();  // If this throws, unlock() never called
    unlock();
}

// ✅ Good - RAII for exception safety
void process() {
    std::lock_guard guard(mutex);
    doWork();  // If this throws, destructor still runs
}
```

---

## ClickHouse Build & CI Specifics

When working on the HyperI fork of ClickHouse (`/projects/ClickHouse`),
these exceptions and requirements override the general C++ standards above.

### Compiler Requirements

- **C++ Standard:** C++23 (`CMAKE_CXX_STANDARD 23`, extensions OFF)
- **CMake:** ≥3.25
- **Compiler:** Clang ONLY — GCC is not supported
- **Clang minimum:** 19 (enforced by CMake fatal error in `cmake/tools.cmake`)
- **Clang in CI:** 21 (`clang-21` / `clang++-21` pinned in `ci/defs/defs.py`)
- **Linker:** LLD ONLY (`ld.lld`). **Gold linker is explicitly forbidden** (CMake fatal error). **mold is NOT supported.**
- **Required LLVM tools:** `llvm-ar`, `llvm-ranlib`, `llvm-objcopy`, `llvm-strip` (version-matched to clang)

### Build Oddities

- `.clang-format` is WebKit-based (140 char columns, 4-space tabs) — NOT the usual LLVM style
- `.clang-tidy` enables all checks then disables ~50 impractical ones. `WarningsAsErrors: '*'`
- `-Xclang -fuse-ctor-homing` flag (debug info size reduction)
- `-falign-functions=64` and `-mbranches-within-32B-boundaries` for stable benchmarks
- ThinLTO for Release/RelWithDebInfo on Linux — but there's a known clang bug where `.debug_aranges` isn't emitted with ThinLTO (CI ships a custom `ld.lld` wrapper as workaround)
- `_LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_EXTENSIVE` in Debug builds
- `-ffile-prefix-map` for reproducible builds
- `ENABLE_CHECK_HEAVY_BUILDS` prevents excessively large translation units

### CI Enforcement

- Uses **Praktika** (custom Python-based CI orchestration, not standard GitHub Actions)
- CI runs in Docker (`clickhouse/binary-builder`, `clickhouse/fasttest`)
- Build types: DEBUG, RELEASE, ASAN, TSAN, MSAN, UBSAN, TIDY, COVERAGE
- Cross-platform: AMD64, ARM64, Darwin, FreeBSD, musl, RISCV64, PPC64LE, S390X
- Uses `sccache` for compilation caching
- PRs require CLA signature via bot
- Build times ~30min+ (full build) — always use sccache

### Contributing (HyperI Fork)

- Follow upstream ClickHouse contribution guidelines for code style
- HyperI-specific changes go in clearly marked sections
- Keep fork patches minimal and rebasing-friendly
- Test against ClickHouse CI docker images locally before pushing

---

## Advanced Patterns (from ClickHouse)

These patterns are battle-tested in ClickHouse for high-throughput data processing.

### Copy-on-Write (COW) Smart Pointers

For sharing large immutable objects with controlled mutation:

```cpp
#include <boost/smart_ptr/intrusive_ptr.hpp>
#include <boost/smart_ptr/intrusive_ref_counter.hpp>

/// Base class for COW objects
template <typename Derived>
class COW : public boost::intrusive_ref_counter<Derived>
{
public:
    using Ptr = boost::intrusive_ptr<const Derived>;       // Immutable, shareable
    using MutablePtr = boost::intrusive_ptr<Derived>;      // Mutable, move-only

    template <typename... Args>
    static MutablePtr create(Args &&... args) {
        return MutablePtr(new Derived(std::forward<Args>(args)...));
    }

    /// Clone only if shared, otherwise reuse
    static MutablePtr mutate(Ptr ptr) {
        if (ptr->use_count() > 1)
            return ptr->clone();
        return const_cast<Derived *>(ptr.get());
    }

protected:
    virtual MutablePtr clone() const = 0;
};

/// Helper for derived classes
template <typename Base, typename Derived>
class COWHelper : public Base
{
public:
    typename Base::MutablePtr clone() const override {
        return typename Base::MutablePtr(new Derived(*static_cast<const Derived *>(this)));
    }
};

// Usage:
// Column::Ptr x = Column::create(data);  // Create mutable, assign to immutable
// Column::Ptr y = x;                      // Share (no copy)
// Column::MutablePtr m = Column::mutate(std::move(x));  // Clone if shared
// m->modify();                            // Safe to modify
// x = std::move(m);                       // Back to immutable
```

**When to use COW:**

- Large objects (columns, blocks) shared across query pipeline
- Need precise control over when copying happens
- Want to avoid locks for read-only access

### PODArray with SIMD Padding

Array optimised for numeric data with SIMD-safe access:

```cpp
/// Key design decisions:
/// - No initialisation (unlike std::vector) - faster for POD types
/// - Right padding for SIMD overread (default 64 bytes)
/// - Left padding for offset-to-size conversion (-1 element access)
/// - Non-copyable to prevent accidental copies

template <
    typename T,
    size_t initial_bytes = 4096,
    typename TAllocator = Allocator<false>,
    size_t pad_right = 64 - 1,  // SIMD padding
    size_t pad_left = 0>
class PODArray : private TAllocator, private boost::noncopyable
{
    char * c_start = null_pointer_for_empty;
    char * c_end = null_pointer_for_empty;
    char * c_end_of_storage = null_pointer_for_empty;

public:
    /// Safe SIMD read past end (up to pad_right bytes)
    void processWithSIMD() {
        // Can safely read c_end + pad_right without segfault
        for (size_t i = 0; i < size(); i += 8) {
            __m256 v = _mm256_loadu_ps(data() + i);  // Safe even at boundary
            // ...
        }
    }

    /// Efficient bulk insert without per-element init
    void resize(size_t n) {
        reserve(n);
        c_end = c_start + n * sizeof(T);
        // Note: no constructor calls - POD only!
    }
};

/// Type alias for common use
using PaddedPODArray = PODArray<T, 4096, Allocator<false>, 63, 0>;
```

### Arena Allocator with Hybrid Growth

Memory pool that switches from exponential to linear growth:

```cpp
class Arena : private boost::noncopyable
{
    static constexpr size_t pad_right = 64 - 1;  // SIMD safety

    struct MemoryChunk {
        char * begin = nullptr;
        char * pos = nullptr;
        char * end = nullptr;
        std::unique_ptr<MemoryChunk> prev;  // Linked list of chunks

        explicit MemoryChunk(size_t size) {
            begin = static_cast<char *>(alloc(size));
            pos = begin;
            end = begin + size - pad_right;
            ASAN_POISON_MEMORY_REGION(begin, size);  // ASan integration
        }

        ~MemoryChunk() {
            ASAN_UNPOISON_MEMORY_REGION(begin, size());
            free(begin, size());
        }
    };

    size_t initial_size = 4096;
    size_t growth_factor = 2;
    size_t linear_growth_threshold = 128 * 1024 * 1024;  // 128MB

    /// Hybrid growth strategy
    size_t nextSize(size_t min_next_size) const {
        if (head.size() < linear_growth_threshold)
            return std::max(min_next_size, head.size() * growth_factor);
        else
            // Linear growth above threshold to avoid excessive allocation
            return roundUp(min_next_size, linear_growth_threshold);
    }

public:
    char * alloc(size_t size) {
        if (head.pos + size > head.end)
            addMemoryChunk(size);

        char * result = head.pos;
        head.pos += size;
        ASAN_UNPOISON_MEMORY_REGION(result, size);
        return result;
    }

    /// Aligned allocation
    char * alignedAlloc(size_t size, size_t alignment) {
        size_t padding = (alignment - reinterpret_cast<uintptr_t>(head.pos)) & (alignment - 1);
        return alloc(size + padding) + padding;
    }
};
```

### Arena with Free Lists

Enables reuse of freed memory within arena:

```cpp
class ArenaWithFreeLists : private Arena
{
    /// 16 free lists for sizes 16, 32, 64, ... 512KB
    /// Sizes > 64KB bypass arena entirely
    static constexpr size_t max_fixed_block_size = 64 * 1024;

    struct FreeListNode {
        FreeListNode * next;
    };
    std::array<FreeListNode *, 16> free_lists{};

    static size_t findFreeListIndex(size_t size) {
        return bitScanReverse(roundUpToPowerOfTwo(std::max(size, 16ul)) >> 4);
    }

public:
    char * alloc(size_t size) {
        if (size > max_fixed_block_size)
            return static_cast<char *>(::operator new(size));

        size_t idx = findFreeListIndex(size);
        size_t actual_size = 16ul << idx;

        if (free_lists[idx]) {
            // Reuse from free list
            FreeListNode * node = free_lists[idx];
            free_lists[idx] = node->next;
            return reinterpret_cast<char *>(node);
        }

        return Arena::alloc(actual_size);
    }

    void free(char * ptr, size_t size) {
        if (size > max_fixed_block_size) {
            ::operator delete(ptr);
            return;
        }

        size_t idx = findFreeListIndex(size);
        auto * node = reinterpret_cast<FreeListNode *>(ptr);
        node->next = free_lists[idx];
        free_lists[idx] = node;
    }
};
```

### Stack-First Allocator

Avoid heap allocation for small objects:

```cpp
template <typename Base, size_t initial_bytes, size_t Alignment = alignof(std::max_align_t)>
class AllocatorWithStackMemory : private Base
{
    alignas(Alignment) char stack_memory[initial_bytes];
    bool stack_in_use = false;

public:
    void * alloc(size_t size, size_t alignment = 0) {
        if (!stack_in_use && size <= initial_bytes) {
            stack_in_use = true;
            return stack_memory;
        }
        return Base::alloc(size, alignment);
    }

    void free(void * ptr, size_t size) {
        if (ptr == stack_memory) {
            stack_in_use = false;
            return;
        }
        Base::free(ptr, size);
    }
};

// Usage: Small aggregate function states avoid heap allocation
using SmallAllocator = AllocatorWithStackMemory<Allocator<false>, 256>;
```

### Multi-Target SIMD Code

Runtime CPU detection with compile-time specialisation:

```cpp
// Define code for multiple architectures
#define DECLARE_MULTITARGET_CODE(...)                           \
    namespace TargetSpecific::Default { __VA_ARGS__ }           \
    namespace TargetSpecific::SSE42 {                           \
        constexpr auto BuildArch = TargetArch::SSE42;           \
        __VA_ARGS__                                             \
    }                                                           \
    namespace TargetSpecific::AVX2 {                            \
        constexpr auto BuildArch = TargetArch::AVX2;            \
        __VA_ARGS__                                             \
    }                                                           \
    namespace TargetSpecific::AVX512 {                          \
        constexpr auto BuildArch = TargetArch::AVX512;          \
        __VA_ARGS__                                             \
    }

DECLARE_MULTITARGET_CODE(
    size_t countMatches(const char * data, size_t size, char needle) {
        size_t count = 0;
        size_t step = 1;

        if constexpr (BuildArch == TargetArch::AVX2)
            step = 32;
        else if constexpr (BuildArch == TargetArch::SSE42)
            step = 16;

        // Architecture-specific implementation...
        return count;
    }
)

// Runtime dispatch
size_t countMatchesDispatch(const char * data, size_t size, char needle) {
    if (CPU::hasAVX512())
        return TargetSpecific::AVX512::countMatches(data, size, needle);
    if (CPU::hasAVX2())
        return TargetSpecific::AVX2::countMatches(data, size, needle);
    if (CPU::hasSSE42())
        return TargetSpecific::SSE42::countMatches(data, size, needle);
    return TargetSpecific::Default::countMatches(data, size, needle);
}
```

### Adaptive Prefetch Distance

Auto-tune prefetch based on actual latency:

```cpp
class PrefetchingHelper
{
    static constexpr size_t iterations_to_measure = 100;
    static constexpr double assumed_load_latency_ns = 100.0;
    static constexpr size_t min_look_ahead = 4;
    static constexpr size_t max_look_ahead = 32;

    size_t prefetch_look_ahead = 8;
    size_t iteration_count = 0;
    Stopwatch watch;

public:
    void prefetch(const void * ptr) {
        __builtin_prefetch(ptr, 0, 3);  // Read, high temporal locality
    }

    void measureAndAdjust() {
        ++iteration_count;
        if (iteration_count == iterations_to_measure) {
            double ns_per_iteration = watch.elapsedNanoseconds() / iterations_to_measure;
            // More iterations per load latency = larger look-ahead
            prefetch_look_ahead = std::clamp(
                static_cast<size_t>(assumed_load_latency_ns / ns_per_iteration),
                min_look_ahead,
                max_look_ahead
            );
        }
    }

    size_t getLookAhead() const { return prefetch_look_ahead; }
};
```

### Optimised Small memcpy

16-byte SIMD copies for small buffers:

```cpp
/// Assumes: can safely read/write 15 bytes past src/dst
inline void memcpySmallAllowReadWriteOverflow15(
    void * __restrict dst,
    const void * __restrict src,
    size_t n)
{
    while (n > 0) {
        _mm_storeu_si128(
            reinterpret_cast<__m128i *>(dst),
            _mm_loadu_si128(reinterpret_cast<const __m128i *>(src))
        );
        dst = static_cast<char *>(dst) + 16;
        src = static_cast<const char *>(src) + 16;
        n -= 16;
        // Prevent compiler from optimising to memcpy
        __asm__ __volatile__("" : : : "memory");
    }
}

/// Safe version that handles exact boundaries
inline void memcpySmall(void * __restrict dst, const void * __restrict src, size_t n) {
    // Unrolled small copies for common sizes
    switch (n) {
        case 0: return;
        case 1: *static_cast<uint8_t *>(dst) = *static_cast<const uint8_t *>(src); return;
        case 2: *static_cast<uint16_t *>(dst) = *static_cast<const uint16_t *>(src); return;
        case 4: *static_cast<uint32_t *>(dst) = *static_cast<const uint32_t *>(src); return;
        case 8: *static_cast<uint64_t *>(dst) = *static_cast<const uint64_t *>(src); return;
        default: std::memcpy(dst, src, n);
    }
}
```

### Exception with Stack Capture

Rich exception context for debugging:

```cpp
class Exception : public std::exception
{
    int code;
    std::string message;
    std::string format_string;
    std::vector<std::string> format_args;
    std::vector<void *> stack_frames;  // Captured at throw site
    mutable std::atomic<bool> logged{false};

public:
    template <typename... Args>
    Exception(int code_, fmt::format_string<Args...> fmt, Args &&... args)
        : code(code_)
        , message(fmt::format(fmt, std::forward<Args>(args)...))
        , format_string(fmt.get())
        , stack_frames(captureStackFrames())
    {}

    /// Prevent duplicate logging
    void markLogged() const { logged.store(true); }
    bool wasLogged() const { return logged.load(); }

    /// Format with stack trace for debugging
    std::string getFullMessage() const {
        return fmt::format("{}\nStack trace:\n{}", message, formatStackTrace(stack_frames));
    }
};

/// Usage
throw Exception(ErrorCodes::BAD_ARGUMENTS,
    "Invalid value {} for parameter {}: must be positive",
    value, param_name);
```

### Safe Type Casting

Debug-checked downcasts:

```cpp
/// In debug builds: validates type with RTTI
/// In release builds: zero-overhead static_cast
template <typename To, typename From>
inline To assert_cast(From && from)
{
#ifdef NDEBUG
    return static_cast<To>(from);
#else
    if constexpr (std::is_pointer_v<To>) {
        auto * result = dynamic_cast<To>(from);
        if (!result && from)
            throw std::bad_cast();
        return result;
    } else {
        return dynamic_cast<To>(from);
    }
#endif
}

// Usage in hot paths - zero overhead in release
const auto * column = assert_cast<const ColumnVector<Int64> *>(col.get());
```

### Scope Guards with Exception Safety

RAII cleanup that handles exceptions in destructors:

```cpp
#define SCOPE_EXIT(...) \
    auto CONCAT(scope_guard_, __LINE__) = detail::ScopeGuard([&]() { __VA_ARGS__; })

#define SCOPE_EXIT_SAFE(...) \
    SCOPE_EXIT( \
        try { __VA_ARGS__; } \
        catch (...) { tryLogCurrentException(__PRETTY_FUNCTION__); } \
    )

// Block memory limit exceptions during cleanup
#define SCOPE_EXIT_MEMORY(...) \
    SCOPE_EXIT( \
        MemoryTracker::LockExceptionInThread lock; \
        __VA_ARGS__; \
    )

// Both protections combined
#define SCOPE_EXIT_MEMORY_SAFE(...) \
    SCOPE_EXIT( \
        try { \
            MemoryTracker::LockExceptionInThread lock; \
            __VA_ARGS__; \
        } catch (...) { tryLogCurrentException(__PRETTY_FUNCTION__); } \
    )

// Usage
void processWithCleanup() {
    auto * resource = acquireResource();
    SCOPE_EXIT_SAFE( releaseResource(resource); );  // Won't throw

    // ... work that might throw ...
}
```

---

## Project Structure (VSCode Greenfield)

Opinionated structure for new C++ projects optimised for VSCode and high-performance data processing.

### Directory Layout

```text
myproject/
├── .vscode/
│   ├── settings.json          # Project-specific VSCode settings
│   ├── launch.json            # Debug configurations
│   ├── tasks.json             # Build tasks
│   └── c_cpp_properties.json  # IntelliSense configuration
├── cmake/
│   ├── Modules/               # Custom Find*.cmake modules
│   ├── CompilerWarnings.cmake # Warning flags
│   └── Sanitizers.cmake       # Sanitizer configurations
├── contrib/                   # Third-party dependencies (git submodules)
│   ├── googletest/
│   ├── fmt/
│   └── simdjson/
├── src/
│   ├── Common/                # Shared utilities
│   │   ├── Arena.h
│   │   ├── Arena.cpp
│   │   ├── PODArray.h
│   │   └── tests/
│   │       └── gtest_arena.cpp
│   ├── Core/                  # Core types and definitions
│   │   ├── Defines.h
│   │   └── Types.h
│   ├── Module1/               # Feature module
│   │   ├── Parser.h
│   │   ├── Parser.cpp
│   │   └── tests/
│   │       └── gtest_parser.cpp
│   └── Module2/
│       └── ...
├── programs/                  # Executables
│   ├── server/
│   │   └── main.cpp
│   └── client/
│       └── main.cpp
├── tests/
│   ├── integration/           # Integration tests
│   └── benchmark/             # Performance benchmarks
├── docs/
├── scripts/
│   ├── build.sh
│   └── run-tests.sh
├── CMakeLists.txt
├── CMakePresets.json          # CMake presets for common configs
├── .clang-format
├── .clang-tidy
├── .gitmodules
└── README.md
```

### VSCode Configuration Files

**.vscode/settings.json**

```json
{
    "cmake.configureOnOpen": true,
    "cmake.buildDirectory": "${workspaceFolder}/build/${buildType}",
    "cmake.generator": "Ninja",

    "C_Cpp.default.configurationProvider": "ms-vscode.cmake-tools",
    "C_Cpp.default.cppStandard": "c++20",
    "C_Cpp.default.compilerPath": "/usr/bin/clang++",
    "C_Cpp.clang_format_style": "file",
    "C_Cpp.codeAnalysis.clangTidy.enabled": true,
    "C_Cpp.codeAnalysis.clangTidy.useBuildPath": true,

    "editor.formatOnSave": true,
    "editor.rulers": [120],

    "files.associations": {
        "*.h": "cpp",
        "*.inc": "cpp"
    },

    "files.exclude": {
        "**/build*": true,
        "**/.cache": true
    },

    "clangd.arguments": [
        "--background-index",
        "--clang-tidy",
        "--completion-style=detailed",
        "--header-insertion=iwyu",
        "--compile-commands-dir=${workspaceFolder}/build/RelWithDebInfo"
    ]
}
```

**.vscode/launch.json**

```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Debug Program",
            "type": "lldb",
            "request": "launch",
            "program": "${workspaceFolder}/build/Debug/programs/server/myserver",
            "args": [],
            "cwd": "${workspaceFolder}",
            "preLaunchTask": "Build Debug"
        },
        {
            "name": "Debug Unit Tests",
            "type": "lldb",
            "request": "launch",
            "program": "${workspaceFolder}/build/Debug/src/Module1/tests/gtest_parser",
            "args": ["--gtest_filter=*"],
            "cwd": "${workspaceFolder}",
            "preLaunchTask": "Build Debug"
        },
        {
            "name": "Debug with ASan",
            "type": "lldb",
            "request": "launch",
            "program": "${workspaceFolder}/build/ASan/programs/server/myserver",
            "args": [],
            "cwd": "${workspaceFolder}",
            "env": {
                "ASAN_OPTIONS": "detect_leaks=1:halt_on_error=0"
            },
            "preLaunchTask": "Build ASan"
        }
    ]
}
```

**.vscode/tasks.json**

```json
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "Configure Debug",
            "type": "shell",
            "command": "cmake",
            "args": ["--preset", "debug"],
            "problemMatcher": []
        },
        {
            "label": "Build Debug",
            "type": "shell",
            "command": "cmake",
            "args": ["--build", "--preset", "debug"],
            "group": { "kind": "build", "isDefault": true },
            "problemMatcher": "$gcc"
        },
        {
            "label": "Build Release",
            "type": "shell",
            "command": "cmake",
            "args": ["--build", "--preset", "release"],
            "problemMatcher": "$gcc"
        },
        {
            "label": "Build ASan",
            "type": "shell",
            "command": "cmake",
            "args": ["--build", "--preset", "asan"],
            "problemMatcher": "$gcc"
        },
        {
            "label": "Run Tests",
            "type": "shell",
            "command": "ctest",
            "args": ["--preset", "debug", "--output-on-failure"],
            "group": { "kind": "test", "isDefault": true },
            "problemMatcher": []
        }
    ]
}
```

### CMakePresets.json

```json
{
    "version": 6,
    "cmakeMinimumRequired": { "major": 3, "minor": 25, "patch": 0 },
    "configurePresets": [
        {
            "name": "base",
            "hidden": true,
            "generator": "Ninja",
            "binaryDir": "${sourceDir}/build/${presetName}",
            "cacheVariables": {
                "CMAKE_CXX_STANDARD": "20",
                "CMAKE_CXX_STANDARD_REQUIRED": "ON",
                "CMAKE_EXPORT_COMPILE_COMMANDS": "ON"
            }
        },
        {
            "name": "debug",
            "inherits": "base",
            "displayName": "Debug",
            "cacheVariables": {
                "CMAKE_BUILD_TYPE": "Debug",
                "CMAKE_CXX_FLAGS": "-g -O0"
            }
        },
        {
            "name": "release",
            "inherits": "base",
            "displayName": "Release",
            "cacheVariables": {
                "CMAKE_BUILD_TYPE": "Release",
                "CMAKE_CXX_FLAGS": "-O3 -DNDEBUG -march=native"
            }
        },
        {
            "name": "relwithdebinfo",
            "inherits": "base",
            "displayName": "RelWithDebInfo",
            "cacheVariables": {
                "CMAKE_BUILD_TYPE": "RelWithDebInfo",
                "CMAKE_CXX_FLAGS": "-O2 -g -DNDEBUG"
            }
        },
        {
            "name": "asan",
            "inherits": "debug",
            "displayName": "AddressSanitizer",
            "cacheVariables": {
                "CMAKE_CXX_FLAGS": "-g -O1 -fsanitize=address,undefined -fno-omit-frame-pointer"
            }
        },
        {
            "name": "tsan",
            "inherits": "debug",
            "displayName": "ThreadSanitizer",
            "cacheVariables": {
                "CMAKE_CXX_FLAGS": "-g -O1 -fsanitize=thread -fno-omit-frame-pointer"
            }
        }
    ],
    "buildPresets": [
        { "name": "debug", "configurePreset": "debug" },
        { "name": "release", "configurePreset": "release" },
        { "name": "relwithdebinfo", "configurePreset": "relwithdebinfo" },
        { "name": "asan", "configurePreset": "asan" },
        { "name": "tsan", "configurePreset": "tsan" }
    ],
    "testPresets": [
        {
            "name": "debug",
            "configurePreset": "debug",
            "output": { "outputOnFailure": true }
        }
    ]
}
```

### Root CMakeLists.txt

```cmake
cmake_minimum_required(VERSION 3.25)
project(myproject LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Aggressive warnings
include(cmake/CompilerWarnings.cmake)
include(cmake/Sanitizers.cmake)

# Third-party dependencies
add_subdirectory(contrib/fmt)
add_subdirectory(contrib/simdjson)

# Enable testing
enable_testing()
add_subdirectory(contrib/googletest)
include(GoogleTest)

# Our code
add_subdirectory(src/Common)
add_subdirectory(src/Core)
add_subdirectory(src/Module1)
add_subdirectory(programs)
```

### cmake/CompilerWarnings.cmake

```cmake
function(set_project_warnings target)
    set(CLANG_WARNINGS
        -Wall
        -Wextra
        -Werror
        -Wpedantic
        -Wshadow
        -Wcast-align
        -Wconversion
        -Wsign-conversion
        -Wnull-dereference
        -Wdouble-promotion
        -Wformat=2
        -Wold-style-cast
        -Woverloaded-virtual
        -Wnon-virtual-dtor
    )

    if(CMAKE_CXX_COMPILER_ID MATCHES ".*Clang")
        set(PROJECT_WARNINGS ${CLANG_WARNINGS})
    elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
        set(PROJECT_WARNINGS ${CLANG_WARNINGS}
            -Wmisleading-indentation
            -Wduplicated-cond
            -Wduplicated-branches
            -Wlogical-op
        )
    endif()

    target_compile_options(${target} PRIVATE ${PROJECT_WARNINGS})
endfunction()
```

### Module CMakeLists.txt Example

```cmake
# src/Module1/CMakeLists.txt
add_library(module1
    Parser.cpp
)

target_include_directories(module1 PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
target_link_libraries(module1 PUBLIC common core fmt::fmt)
set_project_warnings(module1)

# Tests
if(BUILD_TESTING)
    add_executable(gtest_parser tests/gtest_parser.cpp)
    target_link_libraries(gtest_parser PRIVATE module1 GTest::gtest_main)
    gtest_discover_tests(gtest_parser)
endif()
```

### .clang-format

```yaml
---
Language: Cpp
BasedOnStyle: LLVM

# ClickHouse-inspired settings
IndentWidth: 4
TabWidth: 4
UseTab: Never
ColumnLimit: 120

# Braces on own lines
BreakBeforeBraces: Allman
AllowShortFunctionsOnASingleLine: Inline
AllowShortIfStatementsOnASingleLine: Never
AllowShortLoopsOnASingleLine: false

# Spaces
SpaceAfterCStyleCast: true
SpaceBeforeParens: ControlStatements
SpacesInAngles: false
SpaceAroundPointerQualifiers: Both  # const char * ptr

# Includes
IncludeBlocks: Regroup
IncludeCategories:
  - Regex: '^<.*\.h>'
    Priority: 1
  - Regex: '^<.*>'
    Priority: 2
  - Regex: '.*'
    Priority: 3
SortIncludes: CaseSensitive

# Alignment
AlignAfterOpenBracket: Align
AlignConsecutiveAssignments: false
AlignConsecutiveDeclarations: false
AlignOperands: true
AlignTrailingComments: true

# Other
PointerAlignment: Middle  # char * ptr
ReferenceAlignment: Middle
DerivePointerAlignment: false
ReflowComments: true
...
```

### Recommended VSCode Extensions

```json
// .vscode/extensions.json
{
    "recommendations": [
        "ms-vscode.cpptools",
        "ms-vscode.cmake-tools",
        "llvm-vs-code-extensions.vscode-clangd",
        "vadimcn.vscode-lldb",
        "xaver.clang-format",
        "twxs.cmake",
        "ms-vscode.cpptools-extension-pack"
    ]
}
```

---

## Resources

**Standards and Guidelines:**

- [C++ Core Guidelines](https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines)
- [ClickHouse C++ Style Guide](https://clickhouse.com/docs/development/style)
- [Google C++ Style Guide](https://google.github.io/styleguide/cppguide.html)

**Tools:**

- [Clang-Tidy](https://clang.llvm.org/extra/clang-tidy/)
- [AddressSanitizer](https://github.com/google/sanitizers)
- [Compiler Explorer](https://godbolt.org/) - Interactive assembly analysis

**SIMD:**

- [Intel Intrinsics Guide](https://www.intel.com/content/www/us/en/docs/intrinsics-guide/index.html)
- [Highway SIMD Library](https://github.com/google/highway)
- [simdjson](https://github.com/simdjson/simdjson)

**Performance:**

- [Algorithmica - High Performance Computing](https://en.algorithmica.org/hpc/)
- [CppCon YouTube Channel](https://www.youtube.com/user/CppCon)

---

## For AI Code Assistants

The following sections are specific guidance for AI code assistants working with C++.

---

## AI Pitfalls to Avoid

**Before generating C++ code, check these patterns:**

### DO NOT Generate

```cpp
// ❌ Using new/delete directly
Node * node = new Node();
delete node;
// ✅ Use smart pointers
auto node = std::make_unique<Node>();

// ❌ C-style casts
int value = (int)ptr;
// ✅ Use C++ casts
int value = static_cast<int>(ptr);  // Or reinterpret_cast if needed

// ❌ NULL or 0 for null pointers
Node * ptr = NULL;
Node * ptr = 0;
// ✅ Use nullptr
Node * ptr = nullptr;

// ❌ C-style arrays in interfaces
void process(int arr[], size_t size);
// ✅ Use std::span or std::array
void process(std::span<int> arr);

// ❌ std::endl (flushes buffer, slow)
std::cout << "Message" << std::endl;
// ✅ Use '\n' for newlines
std::cout << "Message\n";

// ❌ Catching by value
catch (std::exception e) { }
// ✅ Catch by const reference
catch (const std::exception & e) { }

// ❌ Returning reference to local
std::string & getName() {
    std::string name = "test";
    return name;  // DANGLING
}
// ✅ Return by value
std::string getName() {
    return "test";  // Move semantics, efficient
}

// ❌ Using std::bind (verbose, slow)
auto fn = std::bind(&Class::method, obj, std::placeholders::_1);
// ✅ Use lambdas
auto fn = [&obj](auto arg) { return obj.method(arg); };
```

### Thread Safety Issues

```cpp
// ❌ Race condition
static int counter = 0;
void increment() { counter++; }  // Not atomic!
// ✅ Use atomic
static std::atomic<int> counter{0};
void increment() { counter.fetch_add(1, std::memory_order_relaxed); }

// ❌ Double-checked locking without atomics (broken)
if (!initialised) {
    std::lock_guard lock(mutex);
    if (!initialised) {
        value = compute();
        initialised = true;  // May be reordered!
    }
}
// ✅ Use std::call_once or atomic with proper ordering
std::call_once(init_flag, [&]() { value = compute(); });
```

### Memory Safety

```cpp
// ❌ Use after move
auto ptr = std::make_unique<Data>();
process(std::move(ptr));
ptr->value = 10;  // UNDEFINED

// ❌ Dangling string_view
std::string_view view = std::string("temp");  // Dangling!

// ❌ Iterator invalidation
for (auto & item : vec) {
    if (shouldRemove(item))
        vec.erase(&item);  // UB: invalidates iterators
}

// ❌ Forgetting virtual destructor
class Base {
public:
    ~Base() {}  // Should be virtual if used polymorphically
};
// ✅
class Base {
public:
    virtual ~Base() = default;
};
```

### Performance Anti-Patterns

```cpp
// ❌ Unnecessary copies
void process(std::vector<int> data) { }  // Copies on every call
// ✅ Pass by const reference or span
void process(std::span<const int> data) { }

// ❌ String concatenation in loop
std::string result;
for (const auto & s : strings) {
    result = result + s;  // O(n²) - creates new string each iteration
}
// ✅ Use reserve and append
std::string result;
result.reserve(totalSize);
for (const auto & s : strings) {
    result += s;  // O(n) - appends in place
}

// ❌ Allocating in hot loop
for (size_t i = 0; i < count; ++i) {
    auto vec = std::vector<int>(size);  // Allocates every iteration
    process(vec);
}
// ✅ Pre-allocate and reuse
std::vector<int> vec(size);
for (size_t i = 0; i < count; ++i) {
    std::fill(vec.begin(), vec.end(), 0);  // Reuse allocation
    process(vec);
}
```

### Verify Before Suggesting

```cpp
// ❌ These headers/features may not exist or differ:
#include <format>        // C++20, not all compilers
#include <expected>      // C++23
#include <generator>     // C++23

// ✅ Check compiler support or use alternatives:
// - fmt library as format alternative
// - tl::expected as std::expected alternative
// - range-v3 as ranges alternative

// ❌ Hallucinated functions
std::string::contains()  // C++23 only
std::ranges::to<>()      // C++23 only

// ✅ Use portable alternatives
str.find(substr) != std::string::npos  // Pre-C++23
```
