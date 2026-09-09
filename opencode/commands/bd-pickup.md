---
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*), Bash(bd:*), Read, Glob
description: Pick up where you left off with the beads CLI tool.
---

## Context

- Run this command to see what tasks are available: `bd list`
- Plan files are stored in `~/.claude/plans/`

## Your task

1. **Get available tasks**:
   - Run `bd list` to see what tasks are currently open in the beads CLI
   - Parse the output to understand available tasks (IDs, descriptions, status, etc.)
   - **If there are no tasks**: Inform the user "No open tasks in beads CLI" and stop here
   - **If there are tasks**: Keep this information and continue to the next steps

2. **Select a plan**:
   - Use Glob to find all plan files in `~/.claude/plans/` directory (pattern: `~/.claude/plans/*.md` or similar)
   - If plan files are found:
     - For each plan file, read only the top 20 lines using the Read tool (we want to avoid loading context here)
     - Extract the top heading (usually a # heading in markdown)
     - Use AskUserQuestion to prompt the user to choose one:
       - label: Use just the filename (not the full path)
       - description: Use the top heading/title from the plan file content
       - Mention in the question prompt how many tasks are available from bd list (e.g., "You have 5 open tasks. Which plan would you like to use?")
       - Include a "No plan / Skip" option so the user can proceed without a plan
   - If no plan files exist in the directory or user chooses to skip, continue without a plan
   - When the user chooses a plan, read the full content of the selected plan file for reference

3. **Select task**:
   - Use AskUserQuestion to present the tasks from `bd list`
   - For each task, show rich information:
     - label: Task ID or task name (keep it concise)
     - description: Include task description, status, priority, or any other relevant metadata from bd list
   - If a plan was selected, consider its context:
     - 
     - Mention in descriptions if a task is referenced in the plan
     - You could reorder to show plan-relevant tasks first
   - Present all available tasks as options for the user to choose

4. **Execute the selected task**:
   - Once the user selects a task, proceed with working on it
   - Reference the plan file throughout execution if it was provided
   - Use the TodoWrite tool to track progress as you work on the task 
