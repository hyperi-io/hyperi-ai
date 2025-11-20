# AI Code Assistant Principles

**Research, background, and methodology for AI-assisted development**

---

## Core Principle: Human-First Design

**⚠️ CRITICAL: AI-assisted projects must be indistinguishable from human-only projects.**

**The Goal:**
When a human developer first encounters this codebase, the **cognitive load** should be **the same or less** than a human-only project. No AI-generated artifacts, patterns, or structures that require "translation."

### Why Cognitive Load Matters

**Cognitive Load Theory** (Sweller, 1988) demonstrates that human working memory is severely limited (~4-7 concepts simultaneously). Poor code quality increases cognitive load, making software harder to understand, maintain, and modify.

**Research indicates:**

- Poor source code lexicon/readability significantly increases developers' cognitive load (Scalabrino et al., 2018 - ACM ICPC)
- Source-code metrics and cognitive load are measurably linked (Fakhoury et al., 2023 - systematic tertiary review)
- High cognitive load during code comprehension leads to slower onboarding, debugging difficulty, and decreased productivity
- Complex conditionals, deep nesting, and unnecessary abstractions create **extraneous cognitive load** (avoidable complexity)
- Simple, explicit code with meaningful names reduces cognitive burden and accelerates understanding

**Derek's AI/Human Hobby Horse:**

This isn't just theory - it's measurable. Research indicates that poor code quality increases cognitive load, which directly impacts developer productivity, onboarding time, and bug rates. AI-generated code often violates these principles through verbosity, premature abstraction, and marketing-style documentation. The goal of these standards is to ensure AI-assisted code doesn't increase cognitive load compared to human-written code.

**Academic Papers (ResearchGate - Free Access):**

- Scalabrino, S., et al. (2018). "The Effect of Poor Source Code Lexicon and Readability on Developers' Cognitive Load." [ResearchGate](https://www.researchgate.net/publication/323933178_The_Effect_of_Poor_Source_Code_Lexicon_and_Readability_on_Developers'_Cognitive_Load) | [ACM (paywall)](https://dl.acm.org/doi/10.1145/3196321.3196347)

**Videos:**

- John Sweller (2017). "Without an Understanding of Human Cognitive Architecture, Instruction is Blind" - 43min keynote at researchED Melbourne. [Watch on EPPIC](https://eppic.biz/2020/01/26/td-video-john-sweller-on-cognitive-load-theory/)

**Articles:**

- Florian Krämer (2024). ["The Limits of Human Cognitive Capacities in Programming and Their Impact on Code Readability"](https://florian-kraemer.net/software-architecture/2024/07/25/The-Limits-of-Human-Cognitive-Capacities-in-Programming.html) - Excellent blog post on cognitive load, working memory limits, and code complexity metrics
- ["The Cognitive Load Theory in Software Development"](https://thevaluable.dev/cognitive-load-theory-software-developer/) - Comprehensive guide covering intrinsic, extraneous, and germane load
- Rustam Zakirullin. ["Cognitive Load in Software Development"](https://github.com/zakirullin/cognitive-load) - GitHub living document with practical principles (updated Oct 2025)
- DabApps (2024). ["Programming and Cognitive Load"](https://www.dabapps.com/insights/cognitive-load-programming/) - How maintainable software depends on controlling cognitive load

**Practical implications:**

- **Intrinsic load** = inherent task difficulty (unavoidable)
- **Extraneous load** = unnecessary complexity from poor code design (reducible)
- **Germane load** = beneficial cognitive effort that builds understanding (desirable)

**Goal: Minimize extraneous load** by writing straightforward, human-readable code.

**Learn more:**

- [The Cognitive Load Theory in Software Development](https://thevaluable.dev/cognitive-load-theory-software-developer/) (comprehensive guide)
- [Cognitive Load: What Matters](https://github.com/zakirullin/cognitive-load) (practical principles)

### Context Switching and Cognitive Load

**Senior developers often work on multiple projects** - this is reality, not an anti-pattern. However, context switching between projects significantly amplifies cognitive load.

**Research indicates:**

- **23-45 minute recovery time** after interruption (Carnegie Mellon University)
  - Simple tasks: ~23 minutes to rebuild focus
  - Complex coding tasks: ~45 minutes to full refocus
- **Attention residue** (Sophie Leroy, NYU) - attention remains engaged in previous task when performing current task
  - Revisiting a 5-day-old PR means higher cognitive load, especially if poorly documented
- **Productivity loss:** 20% with 2 concurrent projects, 40% with 3 projects, 75% with 5 projects (Gerald Weinberg)
- **Annual cost:** $50,000 per developer in lost productivity (2024 research)
- **Code quality impact:** Higher bugs, reduced effectiveness, increased pressure (Carnegie Mellon)

**Strategies to reduce context switching overhead:**

1. **Self-documenting code** (CRITICAL when switching projects):
   - Clear variable/function names (no abbreviations)
   - Explicit logic (early returns, simple conditionals)
   - Meaningful commit messages (explain WHY, not WHAT)
   - README with quick-start instructions

2. **Project-specific context files** (in project root):
   - `STATE.md` - Current status, recent work, next tasks
   - `TODO.md` - Prioritized task list
   - `ARCHITECTURE.md` - Key design decisions
   - `.claude/CONTEXT.md` - AI assistant context (architecture, patterns, gotchas)

3. **Minimize "mental model rebuild time":**
   - Consistent patterns across projects (use HyperSec standards)
   - Same infrastructure (hs-lib, HS-CI)
   - Same tools (pytest, ruff, black, mypy)
   - Same deployment pattern (k8s + HELM + ArgoCD)

4. **Time-boxing context switches:**
   - Block minimum 2-hour chunks per project (avoid < 23min sessions)
   - Morning: Project A, Afternoon: Project B (don't ping-pong)
   - Use calendar blocking to protect deep work time

5. **Document before switching:**
   - Update STATE.md with current status
   - Commit WIP with `wip:` prefix (branch, don't commit to main)
   - Leave clear TODO comment at stopping point
   - Run tests before switching (don't leave broken state)

**AI-assisted code must support context switching:**

- ❌ AI generates verbose code that requires mental translation → HIGH context switching cost
- ❌ AI uses project-specific patterns → rebuilding mental model takes longer
- ❌ AI commits lack context → "What was I doing 5 days ago?" overhead
- ✅ Human-readable code → lower cognitive load when returning to project
- ✅ Standard patterns (HyperSec) → mental model transfers between projects
- ✅ Meaningful commits/docs → faster "resume" time

**Accessible References:**

- [Context Switching: The Silent Killer of Developer Productivity](https://www.hatica.io/blog/context-switching-killing-developer-productivity/) (2024)
- [The Hidden Cost of Developer Context Switching](https://dev.to/teamcamp/the-hidden-cost-of-developer-context-switching-why-it-leaders-are-losing-50k-per-developer-1p2j) (2024, DEV Community)
- [Impact of task switching and work interruptions](https://www.researchgate.net/publication/317989659_Impact_of_task_switching_and_work_interruptions_on_software_development_processes) (ResearchGate)

### Why This Matters for AI-Assisted Code

AI assistants often generate code with **high extraneous load:**

- Verbose variable names and over-commenting ("self-documenting" taken too far)
- Premature abstractions and unnecessary design patterns
- Marketing-style documentation instead of factual explanations
- Overly nested logic when early returns would suffice
- Framework coupling that forces new developers to learn "magic" first

**Result:** Humans encountering AI-generated code must:

1. Parse verbose AI conventions
2. Distinguish real complexity from AI verbosity
3. Learn project-specific "AI style"
4. Mentally translate code to human patterns

**This violates the Core Principle** - humans should **not** experience higher cognitive load than a human-only codebase.

### Standards Enforcement

**Design Principle: Test-Enforceable Standards**

**The development and automation of test-enforceable standards is a design principle to make AI assistants more reliable and efficient.**

**Why this matters:**
- AI assistants are probabilistic (not deterministic) - they make mistakes
- Automated testing catches AI errors before code reaches production
- Test-enforceable standards provide clear success criteria for AI
- Reduces need for manual code review and verification
- Enables faster iteration (AI gets immediate feedback from tests)

**Test-enforceable standards include:**
- **Code formatting:** black, ruff (auto-fix available, ruff I rules handle import sorting)
- **Type checking:** mypy (catches type errors)
- **Security:** bandit (catches common vulnerabilities)
- **Code quality:** ruff (PEP 8, import sorting via I rules, unused imports, complexity)
- **Test coverage:** pytest-cov (minimum 80%)
- **Dead code:** vulture (finds unused code)
- **Git conventions:** commit-msg hooks (validates format)

**Non-test-enforceable standards** (require human judgment):
- Code clarity and readability
- Appropriate abstraction level (YAGNI)
- Business logic correctness
- User experience decisions
- Architecture patterns

**This Means:**
- ✅ Use HyperSec/HS-CI standards (work for both humans and AI)
- ✅ Write commits like humans do (see GIT.md)
- ✅ Code should be simple and readable (not over-engineered)
- ✅ Documentation should be factual (not enthusiastic)
- ✅ AI attribution in git footer only (not in code/docs)
- ✅ Minimize extraneous cognitive load (simplify conditionals, early returns, avoid premature abstraction)
- ✅ **Run automated checks after AI generates code** (`./ci/run test`)
- ✅ **Let tests define success criteria** (test-first development)

**Test:**
If a human can't tell whether code/commits were AI-assisted or human-written, you've succeeded.

**See:**
- [GIT.md](../GIT.md#human-style-git-commits-not-llm-style) - Human-style commits
- [NO-MOCKS-POLICY.md](NO-MOCKS-POLICY.md) - No AI placeholders in production
- [TEST-FIRST-DEVELOPMENT.md](TEST-FIRST-DEVELOPMENT.md) - Write tests, not AI prompts
- [DESIGN-PRINCIPLES.md](DESIGN-PRINCIPLES.md) - KISS, YAGNI, simplicity over cleverness

---

## AI-Generated Code Quality Warning

### Research Findings (2024)

⚠️ **AI code completion has significant quality issues:**

**Defect Rates:**
- **4x higher defects** compared to human-written code
- Higher severity bugs (logic errors, not just style)
- More subtle bugs that pass initial testing

**Development Speed:**
- **19% longer completion time** (despite autocomplete!)
- More time spent debugging AI-generated code
- False sense of productivity

**Security Vulnerabilities:**
- More common in AI-generated code
- AI doesn't understand security context
- Often suggests insecure patterns (SQL injection, XSS, etc.)

**Source:** Multiple 2024 studies on AI code generation quality

### Why AI Code Has More Defects

**AI doesn't understand:**
- Business logic context
- Security implications
- Performance characteristics
- Edge cases and error paths
- Domain-specific constraints

**AI tends to:**
- Generate "happy path" code only
- Miss error handling
- Use simplified/incorrect algorithms
- Copy insecure patterns from training data
- Generate plausible-looking but wrong code

---

**See also:**
- [AI-GUIDELINES.md](AI-GUIDELINES.md) - Practical guidelines for AI-assisted development
- [CODING-STANDARDS.md](../CODING-STANDARDS.md) - Core coding standards
- [DESIGN-PRINCIPLES.md](DESIGN-PRINCIPLES.md) - SOLID, DRY, KISS, YAGNI
