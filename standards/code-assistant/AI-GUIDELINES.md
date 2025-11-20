# AI Code Assistant Guidelines

**Operational instructions for AI assistants - generate human-quality code**

⚠️ **CRITICAL:** AI-assisted projects must be indistinguishable from human-only projects.

**Background:** [AI-PRINCIPLES.md](../../docs/AI-PRINCIPLES.md) (research, cognitive load, defect rates)

---

## Core Requirements

**Every AI assistant MUST:**
1. ✅ Write code indistinguishable from human developers
2. ✅ Minimize cognitive load (simple > clever, explicit > implicit)
3. ✅ Follow HyperSec/HS-CI standards exactly
4. ✅ Support context switching (clear names, meaningful commits)
5. ✅ Pass automated tests (formatting, types, security, coverage)
6. ✅ Never use placeholders/TODOs in production code
7. ✅ Use correct spelling per context (see Spelling Guide below)

---

## Spelling and Language Guide

### Code: American English

**All source code uses American spelling** (programming language convention):
- ✅ `color`, `initialize`, `optimize`, `analyze`, `serializer`
- ✅ Variable names: `color_code`, `initializer`, `optimizer`
- ✅ Class names: `ColorPicker`, `DataAnalyzer`, `Serializer`
- ✅ Function names: `initialize_app()`, `optimize_query()`, `serialize_data()`
- ❌ NOT: `colour`, `initialise`, `optimise`, `analyse`, `serialiser` in code

**Why:** Consistency with Python stdlib (`initialize`, `color`), frameworks (FastAPI, Django), and global programming conventions. Using Australian spelling in code creates friction with standard libraries and third-party packages.

### Documentation/Comments/Chat: Australian English

**Everything else uses Australian spelling:**
- ✅ Markdown documentation: "colour", "realise", "organise", "favour"
- ✅ Code comments/docstrings: "Initialise the database connection"
- ✅ Chat responses: "This should help you organise the data"
- ✅ Commit messages: "fix: optimise query performance"
- ✅ README/docs: "Colour-coded output", "Realise the benefits"

**Common Australian vs American pairs:**
- organise/organize, realise/realize, optimise/optimize, analyse/analyze
- colour/color, favour/favor, behaviour/behavior
- serialise/serialize, initialise/initialize, finalise/finalize

### Examples

**✅ Correct - American in code, Australian in comments:**
```python
def initialize_color_picker():
    """Initialise the colour picker component."""  # Australian
    color = "#FF0000"  # American variable name
    return ColorPicker(color)  # American class/param

class DataSerializer:  # American class name
    """Serialise data to JSON format."""  # Australian docstring

    def serialize(self, data):  # American method name
        """Serialise the provided data."""  # Australian docstring
        pass
```

**❌ Wrong - Australian in code:**
```python
def initialise_colour_picker():  # WRONG - Australian in code
    colour = "#FF0000"  # WRONG - Australian in code
    return ColourPicker(colour)  # WRONG
```

**❌ Wrong - American in documentation:**
```python
def initialize_color_picker():
    """Initialize the color picker component."""  # WRONG - American in docs
```

---

## Communication Style

**Use professional, relaxed Australian style - no LLM fluff**

### Core Principles

1. **Direct and concise** - Get to the point, no verbose explanations
2. **No LLM cheerleading** - Skip phrases like "Great question!", "Absolutely!", "I'd be happy to help!"
3. **Technical accuracy over politeness** - If something's wrong, say so directly
4. **Show, don't tell** - Prefer code examples over lengthy descriptions

### What to Avoid (LLM Cheerleading)

❌ **Don't say:**
- "Great question! I'd be happy to help you with that!"
- "Absolutely! Let me walk you through this step by step..."
- "I hope this helps! Let me know if you have any other questions!"
- "I'm excited to share...", "I'd be delighted to..."
- Over-explaining obvious concepts

### What to Avoid (American Marketing Hype)

❌ **Don't say:**
- "This is an AMAZING feature that will revolutionize your workflow!"
- "Incredible performance boost!", "Game-changing architecture!"
- "World-class implementation!", "Fantastic opportunity!"
- "Cutting-edge solution!", "Industry-leading approach!"
- "Best-in-class implementation!", "Transformative results!"

✅ **Say instead (Australian understated):**
- "This feature should help with your workflow"
- "Performance is improved", "Architecture is reorganised"
- "Implementation is working", "Current solution"
- "Standard approach", "Results as expected"

### Tone Characteristics

- ✅ Relaxed but professional
- ✅ Understated (don't oversell)
- ✅ Direct and honest
- ✅ Practical, not promotional
- ✅ Factual without being dry
- ✅ Helpful without being pushy

### Example Responses

**❌ Bad (LLM fluff):**
> "Great question! I'd be absolutely delighted to help you understand this fascinating aspect of Python! Let's explore this together step by step. First, we'll need to consider..."

**✅ Good (direct, professional):**
> "The issue is the async context manager isn't being awaited properly. Fix it like this: [code example]"

### Session Startup

1. **Skip the pleasantries** - No "How can I help you today?" Just acknowledge ready state
2. **Assume context** - You've read the docs, jump straight to work
3. **Be proactive** - If you spot issues while working, mention them
4. **No greetings or confirmations** - Load context and wait for first task

---

## Context Window Sizes

| Tool | Context | Best For |
|------|---------|----------|
| Claude Code | 200k-1M | Multi-file refactoring, architecture |
| GitHub Copilot | 8k-200k | Inline completion, single-file edits |
| Cursor | 8k-200k | Multi-model switching |
| Google Gemini | 1M-2M | Entire codebase analysis |
| OpenAI Codex | 8k-32k | Simple code generation |

**Use Claude Code:** Multi-file refactoring, complex reasoning
**Use Copilot:** Individual functions, boilerplate, quick edits
**Use Cursor:** Multi-model flexibility
**Use Gemini:** 100k+ line codebases, multi-modal content

⚠️ **AI-generated code has 4x higher defects** - see [AI-PRINCIPLES.md](../../docs/AI-PRINCIPLES.md)

---

## Review AI Suggestions

**NEVER blindly accept Tab completions:**
- Read every line before accepting
- Check for edge cases
- Verify error handling

**Red flags:**
- Missing error handling
- Hardcoded values
- TODO comments
- Simplified logic
- Missing input validation
- Generic exception catching

---

## Test Thoroughly

**AI code needs MORE testing:**
- 90%+ code coverage required
- Test edge cases explicitly
- Test error paths
- Test with invalid inputs
- Integration tests required

---

## Security Scan

**Run static analysis on ALL AI-generated code:**

```bash
# Python
bandit -r src/
ruff check src/

# All languages: check for common issues
# - SQL injection
# - XSS vulnerabilities
# - Path traversal
# - Command injection
# - Hardcoded secrets
# - Insecure random number generation
```

---

## Simplify Prompts

**Complex prompts = worse code**

❌ **Bad:** "Create a function that fetches user data from the database, validates it, transforms it to match the API schema, caches it in Redis, and returns it with proper error handling for all failure modes"

✅ **Good (3 iterations):**
```
1. "Create function that fetches user data from database by user_id"
2. "Add validation for user data (email, name required)"
3. "Add error handling for database failures"
```

---

## Iterate and Refine

1. Generate initial code
2. Review for issues
3. Fix specific problems
4. **STOP** - Commit or revert (max 3 iterations)

---

## Tool Best Practices

### GitHub Copilot

**Good context for Copilot:**
```python
def calculate_discount(
    price: float,
    discount_percent: float,
    min_amount: float = 10.0
) -> float:
    """
    Calculate discounted price with business rules.

    Rules:
    - Discount only applies if price >= min_amount
    - Discount percent must be 0-100
    - Price must be positive

    Args:
        price: Original price in USD
        discount_percent: Discount percentage (0-100)
        min_amount: Minimum price to apply discount

    Returns:
        Final price after discount

    Raises:
        ValueError: If price < 0 or discount_percent not in [0, 100]
    """
    # Copilot now has excellent context to generate correct code
```

### Claude Code

**Provide comprehensive context:**
- Architecture (microservices, FastAPI, PostgreSQL, Redis)
- Standards (PEP 8, type hints required, 80% test coverage)
- Security (never log passwords/tokens, validate all inputs)
- Common patterns (use hs-lib for logging/config/metrics)

**Ask for explanations first, not just code:**
```
1. "Explain the architecture of the payment processing system"
2. "What security considerations should I have for payment processing?"
3. "Show me how to implement Stripe payment processing with proper error handling"
4. "Review the code for security issues"
5. "Add comprehensive tests for all error paths"
```

---

## When to Avoid AI

**Don't use AI for:**

**Security-critical code:**
- Authentication systems
- Authorization/permissions
- Encryption/decryption
- Session management
- Password handling

**Complex algorithms:**
- Custom sorting/search
- Graph algorithms
- Dynamic programming
- Mathematical computations
- State machines

**Performance-critical code:**
- Database query optimization
- Caching strategies
- Concurrent/parallel processing
- Memory management
- Hot path optimizations

**Regulatory/compliance code:**
- HIPAA compliance
- GDPR compliance
- PCI-DSS compliance
- SOC 2 controls
- Financial reporting

**Why:** AI doesn't understand security context, produces incorrect logic, and can't profile performance.

---

## AI is Good For

- Boilerplate code generation (CRUD operations)
- Test case generation
- Documentation writing (docstrings)
- Code formatting and style fixes
- Simple CRUD operations

---

## Code Review Checklist

**AI-generated code:**

- [ ] Test coverage > 90%
- [ ] Security scan passes (bandit, semgrep)
- [ ] Performance profiling (no N+1 queries, memory leaks)
- [ ] Edge cases handled
- [ ] Error handling complete
- [ ] No placeholder/mock code
- [ ] Input validation
- [ ] Output validation
- [ ] Logging added
- [ ] Type hints present
- [ ] Docstrings complete
- [ ] No hardcoded values

**Review process:**

1. **Automated checks:** Linters, type checker, security scanner, tests with coverage
2. **Manual review:** Read every line, check error handling, verify edge cases
3. **Integration testing:** Test in real environment, load testing, security testing

---

## Avoiding AI Rabbit-Holing

**Rabbit-holing:** Endless iteration cycles, never reaching "done"

**Warning signs:**
- AI refactoring code from 2 iterations ago
- 5+ changes to same function
- AI suggests "improvements" that don't solve original problem
- Code getting more complex, not simpler
- Working > 30 minutes with no commit
- AI adding abstractions "for future use" (YAGNI violation)

### Strategy 1: Define "Done" Upfront

```markdown
## Task: Add discount calculation

**Done when:**
- [ ] Function accepts price and discount_percent
- [ ] Returns discounted price
- [ ] Validates percent is 0-100
- [ ] Has 3 tests (valid, zero, invalid)
- [ ] Passes all tests

**NOT in scope:** Bulk discounts, seasonal discounts, caching
```

### Strategy 2: Three-Iteration Rule

```
Iteration 1: Generate initial implementation
Iteration 2: Fix obvious issues (tests, validation)
Iteration 3: Polish (formatting, docs)

STOP - Commit or revert
```

### Strategy 3: Time-Box Work

```bash
# 20 minutes for simple feature
# 60 minutes for complex feature
# 120 minutes max for anything

# When timer expires:
# - Tests pass? Commit
# - Tests fail? Revert and try different approach
```

### Strategy 4: Commit Checkpoints

```bash
git commit -m "feat: add basic discount calculation"
# Safe to iterate
git commit -m "feat: add discount validation"
# Can always revert to last good state
```

### Strategy 5: Test-First Iteration

```python
# Define success criteria via tests
def test_calculate_discount():
    assert calculate_discount(100, 10) == 90.0
    assert calculate_discount(100, 0) == 100.0

# Give to AI: "Implement calculate_discount to pass these tests"
# AI can't rabbit-hole - tests define exactly what's needed
```

**See [TEST-FIRST-DEVELOPMENT.md](TEST-FIRST-DEVELOPMENT.md) for details.**

### Strategy 6: YAGNI Enforcement

**Reject AI suggestions that violate YAGNI:**

```
AI: "Let's add caching for future scalability"
You: ❌ REJECT - Not needed now (YAGNI)

AI: "Let's use factory pattern for flexibility"
You: ❌ REJECT - Simple function is fine (KISS)
```

### When to Stop and Commit

**Commit when:**
- ✅ Tests pass
- ✅ Meets definition of "done"
- ✅ No obvious bugs
- ✅ Reasonably simple

**You do NOT need:**
- ❌ Perfect abstraction
- ❌ Every edge case handled
- ❌ Future-proofing
- ❌ 100% coverage
- ❌ AI's approval

### When to Revert

**Revert if:**
- 3+ iterations with no progress
- Code more complex than when you started
- Lost track of what you're solving
- Tests failing and you're not sure why
- AI suggesting contradictory changes

```bash
git reset --hard HEAD~3  # Revert last 3 commits
# Start fresh with clearer task definition
```

### Emergency Escape Hatch

**If deep in a rabbit hole:**

1. Stop immediately
2. Close AI chat
3. Take 5-minute break
4. Re-read original task
5. Check git diff - is code better or just different?
6. Decide: Keep if objectively better, revert if not sure
7. Write down what went wrong

---
