---
description: Commit in bite sized pieces following the service repository pattern
agent: build
---
Make logical commits in this order: 
migrations/sql/repository (database layer) -> services -> the uses of the service methods -> all else

These commits should be small and focused on a single change, with a description that would make it easy to review.

The description should explain the "why" behind the change, not just the "what".

These commits should be easy to bisect if needed,
meaning that each commit should leave the codebase in a working state.

Use conventional commits, like: `fix(sql): this and that`
with a bullet point body describing the change in more detail if needed.
