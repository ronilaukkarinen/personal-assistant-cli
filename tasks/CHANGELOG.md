# 1.1.0: 2024-10-14

* Take into account tomorrow's tasks when scheduling tasks
* If task is in the past, re-schedule it

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