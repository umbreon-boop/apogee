# Contributing to this repository
Welcome, and thank you for your interest in contributing!
This document outlines how to get started, our development standards, and how we keep the project consistent, readable and maintainable.

---
## Table of Contents
- [Overview](#overview)
- [Getting Started](#getting-started)
- [Code Style and Formatting](#code-style-and-formatting)
- [Commit Messages](#commit-messages)
- [Submitting Changes](#submitting-changes)
- [Code of Conduct](#code-of-conduct)

---
## Overview
We welcome all forms of contribution - bug reports, tests, code or feedback, given that you use the proper channels to give them.
Every contribution helps improve the project for everyone.

This guide will help you follow our coding conventions, and submit high-quality changes that can be reviewed and merged smoothly.

---
## Getting Started
### **Install the toolchain**
The only hard dependency is `mise`, which we use to manage everything on a per repository basis. You can install it with:
```bash
curl https://mise.run | sh
```

### **Clone the repository**
```bash
git clone https://github.com/the-unnamed-goose/aria
cd aria
```

### **Create a branch**
```bash
git checkout -b feature/some-new-feature
```

---
## Code Style and Formatting
Basic formatting is applied automatically when running `mise lint`.

### General formatting
- indent with tabs
- double quotes wherever possible
- no trailing commas
- compact table formatting when possible
- 120 characters for line width
- newline required on EOF

### Naming Conventions
- no underscores or dashes in names, with the exception of literals and private members
- names should preferably be one or two words
- abbreviations are not allowed in the module scope
- game services, classes, and methods should be PascalCase
- private members (methods and properties) are prefixed with `_`, e.g. `_ensure`, `_use`, `_cache`.
- all multi-use literals should be SNAKECASE
- all other variable types should be camelCase

### File Structure and Definitions
- all module imports, service references, constants, and variable initializations must appear at the top of the file, preferably in this order
- variable definitions should not include large chains of logical operators but rather make use of if statement expressions
- type annotations are required on the entire public API (parameters and return types); private/internal members do not need them
- defining a custom exported type for a public API's return value is optional as long as the doc comment's `@return` tag correctly documents the shape

### Documentation
Documentation is generated from luadoc style source comments by `mise doc`.

Example:
```lua
--[=[
	A very cool example with an even cooler explanation. Please don't include a newline if there is only one tag.
	@class Exampler
]=]
local Service = game:GetService("UserInputService")
-- in practice each category would be large enough to be worth separating
local Exampler = {}
local LITERAL = "arbitrary value"
local arbitraryValue = if Service then {} else nil

--[=[
  I'm out of ideas for those description paragraphs.

  @class Example
  @prop some boolean Does black box magic
]=]
export type Example = {
	some: boolean,
}

--[=[
  Creates a new instance of Example.
  @return Example
]=]
function Exampler.New(): Example
  return {some = false}
end
```

---
## Commit Messages
We follow conventional commit style:
| Type | Description | Example |
|---|---|---|
| `feat` | New feature | `feat: added position estimations using quantum entanglement` |
| `fix` | Bug fix | `fix: correct approximations of protein folding` |
| `docs` | Documentation update | `docs: add usage section to README` |
| `refactor` | Code change that improves structure | `refactor: optimize metatable logic` |

---
## Submitting Changes
- Keep changes focused and small.
- Run `mise lint` and check everything it flags before submitting.
- Test the modified scripts for bugs and regressions, or get someone to test them for you.
- Reference relevant issues in your commit messages (e.g. `Fixes #42`).
- Changes are reviewed and merged through the platform's pull request system.

---
## Code of Conduct
By contributing, you agree to uphold our Code of Conduct:
- Be respectful and considerate.
- Welcome newcomers and different perspectives.
- Assume positive intent.
- Focus on constructive technical feedback, not personal criticism.

---
Thank You!

Every contribution, no matter the size, helps this project grow. We appreciate your effort, your ideas, and your collaboration.
