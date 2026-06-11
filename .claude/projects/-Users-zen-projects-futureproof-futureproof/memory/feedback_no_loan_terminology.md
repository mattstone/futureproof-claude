---
name: Never use "loan" terminology for EPM
description: EPM is a mortgage product, not a loan — never refer to it as a loan in code, UI text, or conversation
type: feedback
---

Never refer to EPM as a "loan". It is a mortgage. The borrower gets a mortgage on their property, the funds are invested, and the investment returns generate guaranteed monthly income. There are no loan repayments.

**Why:** Using "loan" terminology causes confusion about the product's nature and leads to incorrect UI copy and code naming. EPM is fundamentally different from a traditional loan.

**How to apply:** In all UI text, variable names, comments, and conversation — use "mortgage", "EPM", "Equity Preservation Mortgage", or "Guaranteed Income Plan". Never "loan", "loan activation", "loan details", etc. When encountering existing code that says "loan", flag it but don't rename without permission (existing code may have dependencies).
