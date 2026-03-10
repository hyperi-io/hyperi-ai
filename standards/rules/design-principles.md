<!-- override: manual -->
# Design Principles

## SOLID Principles

- **SRP:** Each class/function should have ONE reason to change. Split multi-concern classes into focused, single-purpose components.
- **OCP:** Open for extension, closed for modification. Add new behavior via inheritance/composition, not by modifying existing stable code with conditionals.
- **LSP:** Subtypes must be substitutable for base types. Never raise exceptions or break contracts that the base type doesn't define.
- **ISP:** Split large interfaces into smaller, specific ones. Clients must not be forced to depend on methods they don't use.
- **DIP:** Depend on abstractions, not concrete implementations. Inject dependencies; never instantiate concrete dependencies inside high-level modules.

❌ `self.db = MySQLDatabase()` inside a service constructor
✅ `def __init__(self, db: Database):` — accept abstraction via injection

## DRY (Don't Repeat Yourself)

- Extract repeated logic into shared functions, classes, or utilities
- Apply the **Rule of Three**: wait until 3+ duplicates before extracting
- Do NOT force DRY when logic merely looks similar but serves different purposes or may diverge
- Duplication is better than the wrong abstraction
- Never create god-functions with type-switching to unify unrelated logic

❌ `def process_entity(entity, type):` with growing if/elif chains
✅ Separate `process_user()` and `process_product()` when logic genuinely differs

## KISS (Keep It Simple, Stupid)

- Favor straightforward solutions over clever tricks
- Avoid over-engineering (no factory-of-factories for simple problems)
- Choose readable code over compact one-liners
- Break complex comprehensions/expressions into named intermediate steps

❌ `result = [x for x in [y**2 for y in range(n) if y % 2] for _ in range(3) if x > 10]`
✅ Split into `odd_numbers`, `squared`, then filter — each step named and clear

- Complexity is justified ONLY when: performance-critical (profiled), security-critical, or unavoidable domain complexity — and must be documented

## YAGNI (You Aren't Gonna Need It)

- Only implement what is needed NOW, not "just in case"
- Do not build abstractions for variations that don't yet exist (e.g., DB adapter layers when using one DB, plugin systems for one plugin)
- Do not make values configurable unless they actually need to change
- Refactor when requirements arrive, not before

- **Build ahead ONLY when:** requirements are certain, cost of later refactor is very high, it's a hard-to-change architecture decision, or it's a security/compliance requirement
