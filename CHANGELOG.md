### 1.4.5: 2025-01-12

* Prevent repetition, change word from note to day planning

### 1.4.4: 2025-01-11

* Add update-changelog.sh script to update the public changelog

### 1.4.3: 2025-01-06

* Fix daily log not showing completed tasks
* Fix AI not adding heading tags

### 1.4.2: 2025-01-01

* Fix Finnish locale not being installed
* Fix task count not being displayed correctly
* Fix jq not being installed
* Use d.m.yyyy format for daily log and batch files

### 1.4.1: 2024-12-19

* Add --no-scheduling option to skip task scheduling completely

### 1.4.0: 2024-12-18

* Skip recurring tasks when scheduling

### 1.3.9: 2024-12-10

* Never remove scheduling of recurring tasks
* Improve prompt to preserve recurring task schedules
* Improve daily log prompt with completed tasks

### 1.3.8: 2024-12-09

* Fix cleanup notes for Obsidian

### 1.3.7: 2024-12-08

* Fix leisure time check
* Fix file paths for Obsidian

### 1.3.6: 2024-12-05

* Change Obsidian note structure to yyyy/mm/dd.md

### 1.3.5: 2024-12-01

* Fix recurring tasks not being scheduled with due_string

### 1.3.4: 2024-11-25

* Make sync-google-calendar-to-todoist.sh standalone

### 1.3.3: 2024-11-23

* Fix version number not printed in scheduled task comments

### 1.3.2: 2024-11-20

* Only schedule tasks for today if they have no specific time set
* Properly remove date from backlog tasks with due_string: "no due date"
* Fix some date commands for macOS
* Fixes to comment on scheduled tasks

### 1.3.1: 2024-11-19

* Add comment to scheduled tasks only if they are scheduled for a different day
* Fix prompt for postponed tasks
* Remove due and duration from Todoist tasks if they are not defined by AI
* Add task to backlog if it's not important
* Fix: Make all events available in the prompt
* Add more notes per task
* Allow missing metadata for tasks
* If date is null, remove datetime from the task
* Refine scheduling prompt

### 1.3.0: 2024-11-12

* Refine prompt

### 1.2.9: 2024-11-12

* Improve prompt to include more tasks to be scheduled

### 1.2.8: 2024-11-12

* Fix all tasks not being scheduled
* Fix cron problem: 08: value too great for base (error token is "08")

### 1.2.7: 2024-11-10

* Fix cronjob
* Fix cleanup notes for multi-day files

### 1.2.6: 2024-11-09

* Fix still occurring issue with remaining hours calculation

### 1.2.5: 2024-11-08

* Fix remaining hours not being calculated correctly
* Change priority to p3 (blue) for calendar event tasks, mistakenly set to p2 (orange) which is 3 in the endpoint
* Fix training task being scheduled 2 hours late

### 1.2.4: 2024-11-07

* Fix priority not being an integer

### 1.2.3: 2024-11-05

* Add priority: 3 to calendar event tasks so that they show up as blue in Todoist

### 1.2.2: 2024-11-03

* Release new version of batch.sh (--one-batch) to schedule tasks for the whole week
* Fix cleanup for batch scheduling

### 1.2.1: 2024-11-01

* Improve postponed task comment date formatting
* Fix extra spacing in daily log

### 1.2.0: 2024-10-30

* Fix offset for event lists
* Fix offset, fix past tasks being re-scheduled
* Fix cleanup
* Postpone further the backlog tasks
* If start day is set, use it as current_day
* Fix start day not parsing properly
* Fix fetching tasks for start day in the main script
* Fix start day for tasks
* Fix right events not counted
* Fix typos
* Improve fetching events without argument
* Improve prompt
* Declare version
* Add prettier message to scheduled task comment

### 1.1.9: 2024-10-29

* Add task metadata template, improve prompt to take account all tasks
* Add tests for Todoist and listing events
* Deprecate gcalcli and use direct Google Calendar API call instead
* Remove postpone function and combine with the schedule function
* Add the list of tasks to be sheculed and links to tasks at the end of the note
* Deprecate GENERAL_PROMPT
* Do not sync focus events back to Todoist
* Add meeting count to note
* Fix filename if scheduling the future
* Fix: Do not schedule anything in the past

### 1.1.8: 2024-10-26

* Fixes and improvements

# 1.1.7: 2024-10-23

* Fix remaining time not saving to the markdown file
* Numerous other fixes
* Ensure no tasks are scheduled prior to 10:00 or during any meetings
* Add the amount of tasks to the daily log output
* Add labels to daily log task list
* Add todoist backup and sync

### 1.1.6: 2024-10-20

* Fix regression: Completed tasks being ignored when syncing calendar events to Todoist
* Capitalize the first letter in the Finnish weekday on note header
* Add GENERAL_PROMPT to the prompt

### 1.1.5: 2024-10-19

* Fix remaining hours not being calculated correctly
* Fix completed tasks being ignored when syncinc calendar events
* Fix Finnish locale for header dates

### 1.1.4: 2024-10-17

* Batch scheduling feature
* Add arguments to its own function
* Improve syncing calendar events, add a label instead of a prefix

### 1.1.3: 2024-10-16

* Disable rate-limiter
* Fix CHANGELOG location
* Change filename to YYYY-MM-DD.md

### 1.1.2: 2024-10-15

* Remove labeling tasks for now when postponed
* Fixes to logic
* Change filename format not to include seconds

### 1.1.1: 2024-10-15

* Change to gpt-4o-mini model
* Add winding down prompt
* Fix logic in postponing tasks
* Suggest more to do
* Do not try to add duration if it's zero

### 1.1.0: 2024-10-15

* Never postpone routines
* Improve prompt
* Clean up only metadata, leave other parts of the notes intact
* Fix Linux timezone issue with scheduling

### 1.0.9: 2024-10-14

* Schedule feature: Add duration and time for tasks in Todoist based on AI recommendations
* Fix replacing the label with now postpone count
* Fix retaining recurrence when postponing tasks
* Fix scheduled task duration unit not being set
* Skip postponing task that is not today
* Improve prompt for AI not to schedule tasks for 00-10
* Fixes to cleanups, sometimes erases most of the notes

### 1.0.8: 2024-10-14

* Add cleanup_notes() function
* Check if schedule has already been made, don't re-do it for the same day
* Add --force option to force schedule
* Fix adding tasks from Google Calendar 3 hours late on Linux
* Fix leisure time not effective on holiday week
* Fix re-adding a calendar event as task even if it's already a completed task
* Do not postpone task if it's already scheduled
* Add postponed count to the task label

### 1.0.7: 2024-10-14

* Fix tasks not crunching correctly for openAI which exceeds the token limit
* Fix some prompts not being specific enough
* Change from too similar notes prompts to general prompts

### 1.0.6: 2024-10-14

* Add rate limiter
* Fix date and grep functions for macOS

### 1.0.5: 2024-10-14

* Add `--help` option
* Add `--days` option to prioritize a number of days
* Skip importing of cancelled events
* Add support syncing multiple events to tasks

### 1.0.4: 2024-10-13

* Improve prompt so that datetime timestamps are always bulletproof
* Add clarification to the prompt that I go try to wind down after 22:00

### 1.0.3: 2024-10-13

* Open changelog
* Fix getting postponed task from metadata
* Improve prompts for postponed tasks