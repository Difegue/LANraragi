
# Contributing to LANraragi

Thank you for your interest in contributing to **LANraragi**! We welcome and appreciate contributions of any size — from typo fixes to new features and translations.

This document outlines how to contribute in a smooth, consistent, and respectful manner.

---

## Table of Contents

1. [Code of Conduct](#code-of-conduct)  
2. [Getting Started](#getting-started)  
3. [How to Contribute](#how-to-contribute)  
   - [Bug Reports & Feature Requests](#bug-reports--feature-requests)  
   - [Pull Requests](#pull-requests)  
   - [Code Review & Feedback](#code-review--feedback)  
   - [Testing](#testing)  
   - [Translations & Localization](#translations--localization)  
   - [Documentation](#documentation)  
   - [Plugins & Extensions](#plugins--extensions)  
4. [Style Guidelines](#style-guidelines)  
5. [Commit Message Format](#commit-message-format)  
6. [Branching & Versioning](#branching--versioning)  
7. [Thank You & Recognition](#thank-you--recognition)  

---

## Code of Conduct

By participating in this project, you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md).  
We expect all contributors to be respectful, considerate, and constructive in all interactions (issues, PRs, discussions, etc.).

---

## Getting Started

1. **Fork** the repository to your own GitHub account.  
2. **Clone** your fork locally:  
   ```bash
   git clone https://github.com/<your-username>/LANraragi.git
   cd LANraragi

3. **Install dependencies**
   Follow the instructions in the [README](README.md) to install prerequisites (Perl modules, Node packages, Redis, etc.).
4. **Run the development server / test environment**
   Make sure you can run LANraragi locally (or in Docker) so you can test changes.

---

## How to Contribute

### Bug Reports & Feature Requests

* Please open an **issue** in the Issues tab.
* Use a clear **title** and describe:

  * What you expected vs. what happened
  * Steps to reproduce (if applicable)
  * Environment (OS, Perl version, browser, CLI vs Docker, etc.)
  * Logs or error output (if any)
* Feel free to propose a **solution** or **rough sketch** for feature requests, but it’s okay if you’re only describing the need.

### Pull Requests

1. Ensure your fork is up-to-date with the upstream `dev` (or main development) branch.
2. Create a new branch, named descriptively (e.g. `fix-duplicate-scan`, `add-opds-filtering`).
3. Make your changes, and **rebase / squash** as appropriate before opening a PR.
4. Include tests (if relevant) and/or manual steps to verify your change.
5. In your PR description:

   * Summarize what the change does and why
   * Reference any related issues (e.g. “Fixes #123”)
   * List any dependencies or side-effects

### Code Review & Feedback

* Be responsive to review comments; sometimes the maintainers may ask for minor adjustments.
* If you disagree with a suggested change, discuss it kindly.
* Upon approval, the maintainer will merge your PR.
* Merged PRs (or donations) are eligible to receive the project’s **sticker pack**. (Details in the README.)

### Testing

* Whenever possible, add or update test cases to cover your changes.
* Run existing tests to ensure nothing breaks.
* For web / UI changes, provide screenshots or short video/gif demos (optional but helpful).
* Document manual testing steps, especially for features that are hard to automate.

### Translations & Localization

* We use Weblate for translation management (see README).
* If you submit translations manually, prefer format and encoding consistent with existing locale files.
* For new languages, create locale files following existing structure.

### Documentation

* Documentation should be kept up-to-date (README, docs, wiki).
* When adding a feature, please document:

  * Configuration options
  * API endpoints (if any)
  * Behavior changes
  * Sample usage
* Prefer clear, concise prose and examples.

### Plugins & Extensions

* LANraragi supports plugins — contributions in this area are welcome.
* Follow the plugin API contracts and include sample usage or tests.
* Document plugin dependencies, version compatibility, and security implications.

---

## Style Guidelines

* Follow existing style and conventions in the codebase.
* Perl: adhere to `perlcritic` and `perltidy` configurations already present.
* JavaScript / CSS / frontend: follow linting rules (ESLint, style formatting) as configured.
* Keep lines reasonably short (e.g. ≤ 100 characters) unless clarity requires otherwise.
* Write clear comments, but avoid redundant or obvious comments.

---

## Commit Message Format

We encourage the following structure for commit messages:

```
<type>(<scope>): <short summary>

<More detailed description — what, why, how>

References: #<issue-number>, #<other-related-issues>
```

* **type**: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`
* **scope**: optional, part of system affected (e.g. `reader`, `api`, `plugin`)
* Short summary: imperative mood, ≤ 50 characters
* Body lines: wrap at ~72 characters

Example:

```
feat(api): support filtering by tag namespace

Add a new query parameter `ns:` to allow filtering entries
by tag namespace in OPDS requests.

Fixes #456
```

---

## Branching & Versioning

* The **dev** branch is the primary development branch; PRs should target it unless otherwise noted.
* Major and minor version releases are tagged (e.g. `v0.9.5`).
* For bugfixes, branch from `dev` (or hotfix branches, if applicable) and merge back into `dev`.
* Keep your branches focused — small, single-purpose changes are easier to review.

---

## Thank You & Recognition

We deeply appreciate every contribution — whether large or small.
Contributors (past and present) are listed in the project's contributors page.
Merged pull requests (and donations above a threshold) may also receive a **sticker pack** as a token of gratitude (details in README).

---

If you’re unsure where to start, you can ask in Discussions or Issues for “help wanted” tags or small beginner tasks.
We look forward to collaborating with you and improving LANraragi together! 🚀

