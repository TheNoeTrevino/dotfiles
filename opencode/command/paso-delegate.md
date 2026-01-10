---
description: Send subagent to complete in progress tasks in the paso cli in parallel. Complete deepest into dependencies first.
agent: build
---
Using the paso cli, do the following:

$ARGUMENTS

Run `paso project tree <project-id>` to identify tasks that are in a ready column. Like "todo".
Verify this with `paso task ready <project-id>`.

For each unblocked task, send a subagent to complete the task. Give the subagent a detailed prompt on how to complete the task, 
which file to look, and to run `paso task show <task-id>` to get more details about the task.
Be sure to instruct the subagent to mark the task as in progress when starting with `paso task move --id 64 'In Progress'`

Remember that we don't want agents stepping on each other's toes, so make sure that each subagents are working on different tasks,
reducing the likelihood of changing the same files at the same time.

Do not move tasks to done until all subagents have completed their work and reported back.

Lint, test, and build the project after all subagents have completed their tasks to ensure everything is working correctly.

Run any other code quality checks that are standard for the project to ensure high code quality.

Then, mark the tasks as done using `paso task done <task-id> --quiet`.

Finally, provide a summary of the completed tasks and any important changes made during the process.
