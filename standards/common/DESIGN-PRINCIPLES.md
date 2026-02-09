# Design Principles

**Detailed guide for SOLID, DRY, KISS, and YAGNI principles**

---

## SOLID Principles

### Single Responsibility Principle (SRP)

**Each class/function should have ONE reason to change**

Split complex classes into focused, single-purpose components.

**Example: Separate concerns**

```python
# Bad - multiple responsibilities
class UserManager:
    def save_user(self, user):
        # Database logic
        db.insert(user)

    def send_welcome_email(self, user):
        # Email logic
        smtp.send(user.email, "Welcome!")

    def generate_report(self, user):
        # Reporting logic
        return f"User Report: {user.name}"

# Good - single responsibilities
class UserRepository:
    def save(self, user):
        db.insert(user)

class EmailService:
    def send_welcome(self, user):
        smtp.send(user.email, "Welcome!")

class UserReportGenerator:
    def generate(self, user):
        return f"User Report: {user.name}"
```

**Why SRP matters:** Easier testing (focused), maintenance (isolated changes), understanding (clear purpose), reuse (single-purpose)

---

### Open/Closed Principle (OCP)

**Open for extension, closed for modification**

Add new features without changing existing, stable code.

**Example: Extension via inheritance**

```python
# Bad - must modify class for new payment types
class PaymentProcessor:
    def process(self, payment_type, amount):
        if payment_type == "credit_card":
            # Credit card logic
            pass
        elif payment_type == "paypal":
            # PayPal logic
            pass
        # Adding new type requires modifying this class!

# Good - extend via inheritance
class PaymentProcessor:
    def process(self, amount):
        raise NotImplementedError

class CreditCardProcessor(PaymentProcessor):
    def process(self, amount):
        # Credit card logic
        pass

class PayPalProcessor(PaymentProcessor):
    def process(self, amount):
        # PayPal logic
        pass

# Add new types without modifying existing classes
class BitcoinProcessor(PaymentProcessor):
    def process(self, amount):
        # Bitcoin logic
        pass
```

**Why OCP matters:**

- Stable code stays stable (no regression risk)
- New features via composition/inheritance
- Easier to scale (add features without breaking existing)

---

### Liskov Substitution Principle (LSP)

**Subtypes must be substitutable for base types**

Don't break contracts in subclasses.

**Example: Honoring base class contracts**

```python
# Bad - breaks base class contract
class Bird:
    def fly(self):
        return "Flying"

class Penguin(Bird):
    def fly(self):
        raise Exception("Penguins can't fly!")  # Violates LSP!

# Good - correct hierarchy
class Bird:
    def move(self):
        raise NotImplementedError

class FlyingBird(Bird):
    def move(self):
        return "Flying"

class Penguin(Bird):
    def move(self):
        return "Swimming"
```

**Why LSP matters:**

- Polymorphism works correctly
- No unexpected exceptions
- Subclasses truly extend base behavior

---

### Interface Segregation Principle (ISP)

**Clients shouldn't depend on interfaces they don't use**

Split large interfaces into smaller, specific ones.

**Example: Focused interfaces**

```python
# Bad - fat interface
class Worker:
    def work(self):
        pass

    def eat(self):
        pass

    def sleep(self):
        pass

class Robot(Worker):
    def work(self):
        return "Working"

    def eat(self):
        raise NotImplementedError  # Robots don't eat!

    def sleep(self):
        raise NotImplementedError  # Robots don't sleep!

# Good - segregated interfaces
class Workable:
    def work(self):
        pass

class Eatable:
    def eat(self):
        pass

class Sleepable:
    def sleep(self):
        pass

class Human(Workable, Eatable, Sleepable):
    def work(self):
        return "Working"

    def eat(self):
        return "Eating"

    def sleep(self):
        return "Sleeping"

class Robot(Workable):
    def work(self):
        return "Working"
```

**Why ISP matters:**

- Clients only depend on what they need
- Smaller, focused interfaces
- Easier to implement and test

---

### Dependency Inversion Principle (DIP)

**Depend on abstractions, not concrete implementations**

High-level modules shouldn't depend on low-level modules.

**Example: Abstract dependencies**

```python
# Bad - depends on concrete implementation
class UserService:
    def __init__(self):
        self.db = MySQLDatabase()  # Tight coupling!

    def get_user(self, user_id):
        return self.db.query(f"SELECT * FROM users WHERE id={user_id}")

# Good - depends on abstraction
class Database:
    def query(self, sql):
        raise NotImplementedError

class MySQLDatabase(Database):
    def query(self, sql):
        # MySQL-specific logic
        pass

class PostgreSQLDatabase(Database):
    def query(self, sql):
        # PostgreSQL-specific logic
        pass

class UserService:
    def __init__(self, db: Database):
        self.db = db  # Depends on abstraction!

    def get_user(self, user_id):
        return self.db.query(f"SELECT * FROM users WHERE id={user_id}")

# Easy to swap implementations
service = UserService(MySQLDatabase())  # or PostgreSQLDatabase()
```

**Why DIP matters:**

- Easy to swap implementations
- Easier to test (mock abstractions)
- Loose coupling

---

## DRY (Don't Repeat Yourself)

**Eliminate code duplication**

Extract repeated logic to functions, classes, or utilities.

### When to Apply DRY

**Duplicate logic (apply DRY):**

```python
# Bad - duplication
def process_user_csv(file):
    data = read_csv(file)
    validate_data(data)
    save_to_db(data)

def process_product_csv(file):
    data = read_csv(file)
    validate_data(data)
    save_to_db(data)

# Good - DRY
def process_csv(file, entity_type):
    data = read_csv(file)
    validate_data(data, entity_type)
    save_to_db(data, entity_type)
```

**Similar but not identical (DON'T force DRY):**

```python
# Don't force DRY if logic diverges
def process_user(user):
    validate_user(user)
    sanitize_user_email(user)
    encrypt_user_password(user)
    save_user(user)

def process_product(product):
    validate_product(product)
    sanitize_product_name(product)
    calculate_product_price(product)
    save_product(product)

# These are similar but serve different purposes
# Forcing DRY would create artificial coupling
```

### DRY Anti-Patterns

**Don't DRY prematurely:**

- Wait until you have 3+ duplicates (Rule of Three)
- Don't extract if logic might diverge
- Duplication is better than wrong abstraction

**Example of wrong abstraction:**

```python
# Bad - forced DRY creates coupling
def process_entity(entity, type):
    if type == "user":
        # User-specific logic
        pass
    elif type == "product":
        # Product-specific logic
        pass
    # Adding more if/elif makes this worse!

# Better - accept some duplication
def process_user(user):
    # User logic
    pass

def process_product(product):
    # Product logic
    pass
```

---

## KISS (Keep It Simple, Stupid)

**Favor simplicity over cleverness**

### Simplicity Guidelines

**Use straightforward solutions:**

- Avoid over-engineering
- Choose readable code over clever tricks
- Simpler code = fewer bugs
- Future maintainers will thank you

### Examples

**❌ Bad (over-engineered):**

```python
# Abstract factory pattern for simple config
class ConfigFactoryFactory:
    def create_factory(self, type):
        return ConfigFactory(type)

class ConfigFactory:
    def __init__(self, type):
        self.type = type

    def create_config(self):
        if self.type == "yaml":
            return YAMLConfig()
        elif self.type == "json":
            return JSONConfig()

factory_factory = ConfigFactoryFactory()
factory = factory_factory.create_factory("yaml")
config = factory.create_config()
```

**✅ Good (simple):**

```python
# Just load the config
config = load_config("config.yaml")
```

**❌ Bad (clever trick):**

```python
# Clever one-liner
result = [x for x in [y**2 for y in range(n) if y % 2] for _ in range(3) if x > 10]
```

**✅ Good (clear):**

```python
# Clear and readable
odd_numbers = [y for y in range(n) if y % 2]
squared = [y**2 for y in odd_numbers]
result = [x for x in squared if x > 10]
```

### When Complexity is Justified

**Complex is OK when:**

- Performance-critical (profiled and proven)
- Security-critical (well-tested)
- Domain complexity (unavoidable)
- But still document and explain it!

---

## YAGNI (You Aren't Gonna Need It)

**Don't add features prematurely**

Only implement what's needed NOW.

### YAGNI Guidelines

**Don't build features "just in case":**

- Wait for actual requirements
- Refactor when needed
- Avoid speculative generality

### Common YAGNI Violations

**❌ Bad examples:**

1. **Database abstraction (when you only use one DB):**

```python
# Don't build this if you only use PostgreSQL
class DatabaseAbstraction:
    def query(self):
        pass

class PostgreSQLAdapter(DatabaseAbstraction):
    pass

class MySQLAdapter(DatabaseAbstraction):
    pass

class MongoDBAdapter(DatabaseAbstraction):
    pass
```

1. **Plugin system (with only one plugin):**

```python
# Don't build plugin infrastructure for one plugin
class PluginManager:
    def load_plugins(self):
        pass

    def register_plugin(self, plugin):
        pass

# Just call the one plugin directly!
```

1. **Unnecessary configuration:**

```python
# Don't make everything configurable
config = {
    "feature_enabled": True,  # You know it's enabled!
    "timeout": 30,            # Just hardcode if it never changes
    "max_retries": 3,         # Add config when actually needed
}
```

### When to Build for the Future

**Build ahead when:**

- Requirements are certain (not speculative)
- Cost of later refactor is very high
- Architecture decision (hard to change later)
- Security/compliance requirement

**Example: Build ahead for known scale:**

```python
# OK to build for scale if growth is certain
class UserService:
    def __init__(self, cache, db):
        self.cache = cache  # Will need caching for scale
        self.db = db
```

---

## See Also

- **Configuration & Logging:** See [CONFIG-AND-LOGGING.md](CONFIG-AND-LOGGING.md) for the HyperI 7-layer config cascade and structured logging standards
