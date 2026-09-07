# Code Formatting Standard

> **Source of Truth**: `coding-standards/.editorconfig` — this document explains the rules.

---

## Overview

Every language in the OElite platform has a canonical formatter sourced from JetBrains Rider and WebStorm defaults. The `.editorconfig` file at the root of `coding-standards/` is the machine-readable source of truth. This document explains each rule, maps it to JetBrains documentation, and provides before/after examples of common AI agent mistakes.

The goal is eliminate formatting debate in code review: the formatter decides, the reviewer checks conformance, and agents format before committing.

---

## Authority Model

| File | Role |
|------|------|
| `coding-standards/.editorconfig` | Machine-readable canonical standard (single source of truth) |
| `coding-standards/formatting-standard.md` | Human-readable explanation, examples, and enforcement guidance |
| `coding-standards/agents/core/principles.md` | HARD GATE making conformance non-negotiable |
| `<repo>/.ai/standards/*.md` | Repo-specific overrides only (deviation-only; must not contradict canon) |

Per-repo `.editorconfig` files that duplicate the canonical standard are prohibited. They may only exist to declare `root = false` and add documented repo-specific exceptions, with a header comment pointing back to this file.

---

## Language-Specific Rules

### C# / .NET (JetBrains Rider)

**Reference**: https://www.jetbrains.com/help/rider/Settings_Code_Style_CSHARP.html

| Rule | Value |
|------|-------|
| Indent size | 4 spaces |
| Brace style | End-of-line (K&R variant) |
| New line before open brace | All contexts |
| Space after `cast` | Yes |
| Space in `if/for/while` parentheses | Yes |
| Space before method `()` | No |
| `var` style | Explicit types preferred; `var` only when type is apparent |

**Source**: JetBrains Rider Code Style settings for C#.

```csharp
// ❌ BEFORE — non-conforming (AI agent common mistake)
public async Task<UserDto?>GetByIdAsync(string id){
    if(id==null) throw new ArgumentNullException(nameof(id));
    var result = await _repo.FindByIdAsync(id);
    return result;
}

// ✅ AFTER — conforming to .editorconfig
public async Task<UserDto?> GetByIdAsync(string id)
{
    if (id == null)
        throw new ArgumentNullException(nameof(id));

    var result = await _repo.FindByIdAsync(id);
    return result;
}
```

---

### TypeScript / TSX / JavaScript (WebStorm)

**Reference**: https://www.jetbrains.com/help/webstorm/settings-code-style-typescript.html

| Rule | Value |
|------|-------|
| Indent size | 2 spaces |
| Semicolons | Required |
| Quote style | Single quotes |
| Import member sorting | Alphabetical |
| Object property alignment | Aligned on value |

**Source**: WebStorm Code Style settings for TypeScript/JavaScript.

```tsx
// ❌ BEFORE — non-conforming (AI agent common mistake)
import React, { useState, useEffect } from "react";
import { formatDate } from "../utils/date";
const [userName,setUserName]=useState("");
useEffect(()=>{fetchUser().then(u=>setUserName(u.name))},[]);

// ✅ AFTER — conforming to .editorconfig
import React, { useEffect, useState } from 'react';
import { formatDate } from '../utils/date';

const [userName, setUserName] = useState('');
useEffect(() => {
    fetchUser().then(u => setUserName(u.name));
}, []);
```

---

### SCSS (WebStorm)

**Reference**: https://www.jetbrains.com/help/idea/code-style-css.html

| Rule | Value |
|------|-------|
| Indent size | 2 spaces |
| Blank lines around nested rules | 1 |
| Closing brace alignment | Not aligned with properties |

```scss
// ❌ BEFORE — non-conforming (AI agent common mistake)
.btn {
    padding: 8px 16px;
    &:hover {
        background: darken($primary,10%);
        cursor: pointer;
    }
    &:active {
        transform: scale(0.98);
    }
}

// ✅ AFTER — conforming to .editorconfig
.btn {
  padding: 8px 16px;

  &:hover {
    background: darken($primary, 10%);
    cursor: pointer;
  }

  &:active {
    transform: scale(0.98);
  }
}
```

---

### Python (WebStorm / PEP 8)

**Reference**: https://www.jetbrains.com/help/idea/code-style-python.html

| Rule | Value |
|------|-------|
| Indent size | 4 spaces |
| Semicolons | No |
| Blank lines around class | 1 |
| Blank lines around method | 1 |
| Max line length | 100 |

```python
# ❌ BEFORE — non-conforming (AI agent common mistake)
def get_user_by_id(user_id:str)->Optional[User]:
    if user_id is None: raise ValueError("user_id required")
    result = db.query(User).filter(User.id==user_id).first()
    return result

# ✅ AFTER — conforming to .editorconfig
def get_user_by_id(user_id: str) -> Optional[User]:
    if user_id is None:
        raise ValueError('user_id required')

    result = db.query(User).filter(User.id == user_id).first()
    return result
```

---

### HTML (WebStorm)

**Reference**: https://www.jetbrains.com/help/idea/code-style-html.html

| Rule | Value |
|------|-------|
| Indent size | 2 spaces |
| Attribute alignment | Aligned |
| Max line length | Off |

---

### JSON (WebStorm)

**Reference**: https://www.jetbrains.com/help/idea/code-style-json.html

| Rule | Value |
|------|-------|
| Indent size | 2 spaces |
| Blank lines in values | 0 |
| Max line length | Off |

---

### YAML (WebStorm)

**Reference**: https://www.jetbrains.com/help/idea/code-style-yaml.html

| Rule | Value |
|------|-------|
| Indent size | 2 spaces |
| Max line length | Off |

---

### Shell / Bash (WebStorm)

**Reference**: https://www.jetbrains.com/help/idea/code-style-shell.html

| Rule | Value |
|------|-------|
| Indent size | 2 spaces |
| POSIX shell style | Enabled (for sh/bash/zsh) |

---

## What Reviewers Should Check

Even when `.editorconfig` is present, reviewers (Grace, Felix, and others) MUST actively check for these common violations:

- **Indent size mismatch**: C# using 2 spaces instead of 4; TS/JS using 4 instead of 2
- **Brace style**: C# braces not on their own line; missing newline before `{` in Rider-enforced contexts
- **Quote style in TS/JS**: Double quotes instead of single quotes
- **Missing semicolons in TS/JS**: Omitted where required
- **Trailing whitespace**: Any line ending with space or tab characters
- **Missing final newline**: Files not ending with a blank line
- **Mixed line endings**: Any `\r\n` on macOS/Linux
- **Import ordering in C#**: `System.*` directives not sorted first, or no blank line between groups
- **Max line length violations**: Lines exceeding 120 characters (C#) or 100 characters (Python), except in generated code
- **Type annotation style in C#**: Inconsistent `var` usage outside JetBrains guidelines

---

## What Reviewers Should NOT Check

- **Line length in generated or auto-formatted output**: Defer to the formatter
- **Brace style debate**: If `.editorconfig` says end-of-line braces, that's the rule — no bikeshedding
- **Minor whitespace-only diffs in third-party or copied code**: Flag it, but don't block the MR
- **Formatting of `.min.js` or asset files**: Not formatted by convention

---

## How to Verify

### Check .editorconfig is present
```bash
cat coding-standards/.editorconfig
```

### IDE auto-application
- **Rider / WebStorm / IntelliJ**: EditorConfig support is enabled by default. The IDE applies these settings automatically when the project is opened.
- **VS Code**: Install the [EditorConfig](https://marketplace.visualstudio.com/items?itemName=EditorConfig.EditorConfig) extension. It reads `.editorconfig` and applies formatting on file save.
- **JetBrains Fleet**: EditorConfig support is built-in.

### Format on demand
- Rider: `Ctrl+Alt+Shift+F` (Reformat Code)
- WebStorm: `Ctrl+Alt+L` (Reformat Code)
- VS Code: `Alt+Shift+F` with the EditorConfig extension

### Pre-commit enforcement (future)
The `.git/hooks/pre-commit` script (pending implementation per a future issue) will run `editorconfig-checker` to validate staged files. This is tracked separately from this issue.

---

## Change History

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2026-09-07 | 1.0 | Isabella | Initial canonical standard — JetBrains Rider/WebStorm defaults documented for C#, TS/TSX, SCSS, HTML, JSON, YAML, Python, Shell |
