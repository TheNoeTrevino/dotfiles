---
description: Run golang lint, test, and formatting checks, fix in parallel
model: claude-haiku-4-5-20251001
agent: build
---

Run `golanglint-ci` our test suite. Fix issues in parallel, if any.

At the end of the process, run:
`gofmt -w .` 

Provide a summary of the issues that were found, and the changes that were made.
