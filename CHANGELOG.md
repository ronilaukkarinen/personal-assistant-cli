# 1.1.9: 2024-10-29

* Add task metadata template, improve prompt to take account all tasks
* Add tests for Todoist and listing events
* Deprecate gcalcli and use direct Google Calendar API call instead
* Remove postpone function and combine with the schedule function
* Add the list of tasks to be sheculed and links to tasks at the end of the note
* Deprecate GENERAL_PROMPT

# 1.1.8: 2024-10-26

* Fixes and improvements

# 1.1.7: 2024-10-23

* Fix remaining time not saving to the markdown file
* Numerous other fixes
* Ensure no tasks are scheduled prior to 10:00 or during any meetings
* Add the amount of tasks to the daily log output
* Add labels to daily log task list
* Add todoist backup and sync

# 1.1.6: 2024-10-20

* Fix regression: Completed tasks being ignored when syncing calendar events to Todoist
* Capitalize the first letter in the Finnish weekday on note header
* Add GENERAL_PROMPT to the prompt

# 1.1.5: 2024-10-19

* Fix remaining hours not being calculated correctly
* Fix completed tasks being ignored when syncinc calendar events
* Fix Finnish locale for header dates

# 1.1.4: 2024-10-17

* Batch scheduling feature
* Add arguments to its own function
* Improve syncing calendar events, add a label instead of a prefix

# 1.1.3: 2024-10-16

* Disable rate-limiter
* Fix CHANGELOG location
* Change filename to YYYY-MM-DD.md

# 1.1.2: 2024-10-15

* Remove labeling tasks for now when postponed
* Fixes to logic
* Change filename format not to include seconds

# 1.1.1: 2024-10-15

* Change to gpt-4o-mini model
* Add winding down prompt
* Fix logic in postponing tasks
* Suggest more to do
* Do not try to add duration if it's zero

# 1.1.0: 2024-10-15

* Never postpone routines
* Improve prompt
* Clean up only metadata, leave other parts of the notes intact
* Fix Linux timezone issue with scheduling

# 1.0.9: 2024-10-14

* Schedule feature: Add duration and time for tasks in Todoist based on AI recommendations
* Fix replacing the label with now postpone count
* Fix retaining recurrence when postponing tasks
* Fix scheduled task duration unit not being set
* Skip postponing task that is not today
* Improve prompt for AI not to schedule tasks for 00-10
* Fixes to cleanups, sometimes erases most of the notes

# 1.0.8: 2024-10-14

* Add cleanup_notes() function
* Check if schedule has already been made, don't re-do it for the same day
* Add --force option to force schedule
* Fix adding tasks from Google Calendar 3 hours late on Linux
* Fix leisure time not effective on holiday week
* Fix re-adding a calendar event as task even if it's already a completed task
* Do not postpone task if it's already scheduled
* Add postponed count to the task label

# 1.0.7: 2024-10-14

* Fix tasks not crunching correctly for openAI which exceeds the token limit
* Fix some prompts not being specific enough
* Change from too similar notes prompts to general prompts

# 1.0.6: 2024-10-14

* Add rate limiter
* Fix date and grep functions for macOS

# 1.0.5: 2024-10-14

* Add `--help` option
* Add `--days` option to prioritize a number of days
* Skip importing of cancelled events
* Add support syncing multiple events to tasks

# 1.0.4: 2024-10-13

* Improve prompt so that datetime timestamps are always bulletproof
* Add clarification to the prompt that I go try to wind down after 22:00

# 1.0.3: 2024-10-13

* Open changelog
* Fix getting postponed task from metadata
* Improve prompts for postponed tasks