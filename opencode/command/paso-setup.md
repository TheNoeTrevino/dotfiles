---
description: Split up current identified tasks into smaller, manageable subtasks with dependency links in the paso cli.
allowed-tools: Bash(paso:*)
argument-hint: <instructions> 
---

Using the paso cli, do the following:

$ARGUMENTS

Organize the current tasks by creating overarching tasks with 'EPIC: ' in the task title. 
Then, create subtasks for the epic with the `--blocks <epic_task_id>` flag.

If needed, make further subtasks under those tasks to break them down into even smaller pieces.
You can use the `--blocks <epic_task_id>` and `--blocked-by <epic_task_id>` flags for this

For example, the output of the `paso project tree <project-id>` command should come out to: 
``` bash
EPIC: Frontend Feature
  L BLOCKER - Add homepage layout
    L BLOCKER - Create Sidebar component
    L BLOCKER - Create Navbar component
```

This should be extremely logical, and follow the agile method of breaking down tasks into smaller,
manageable pieces with clear dependencies.

Once these tasks are organized add comments to each task explaining the purpose of the task and any relevant details like
related files, similar implementations, etc...

For example, for the task "Create navbar layout", you might add a comments like:
  - If a user is logged in, show their profile picture and a logout button.
  - Use the @./services/auth-service.ts to determine if a user is logged in, and adjust the navbar accordingly.

Run the `paso project tree <project-id>` to ensure everything looks correct. Then, give suggestions on what epic should be worked on. 
