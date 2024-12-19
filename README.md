# 🤖 Personal Assistant CLI Tool

![bash](https://img.shields.io/badge/bash-%23121011.svg?style=for-the-badge&color=%23222222&logo=gnu-bash&logoColor=white) ![Chagtgpt](https://img.shields.io/badge/OpenAI-74aa9c?style=for-the-badge&logo=openai&logoColor=white) ![Google Cloud](https://img.shields.io/badge/GoogleCloud-%234285F4.svg?style=for-the-badge&logo=google-cloud&logoColor=white) ![Obsidian](https://img.shields.io/badge/Obsidian-%23483699.svg?style=for-the-badge&logo=obsidian&logoColor=white) ![Todoist](https://img.shields.io/badge/todoist-badge?style=for-the-badge&logo=todoist&logoColor=%23ffffff&color=%23E44332)

## Prioritize tasks for Todoist, save a note of the briefing to Obsidian, sync Google Calendar events to Todoist as tasks 🦾

> [!NOTE] 
> **Please note!** This project uses hardcoded Finnish language strings and is 100% meant for my personal usage. The prompt is in Finnish, the tasks are in Finnish, and the output is in Finnish. If you want to use this, you need to modify the script to your own language and needs.

This is a Bash-based tool that prioritizes your daily tasks using [OpenAI's GPT-4o-mini model](https://openai.com/index/gpt-4o-mini-advancing-cost-efficient-intelligence/). It integrates tasks from Todoist and events from Google Calendar to create a comprehensive view of your day, allowing you to make informed decisions about what to prioritize.

This tool is perfect for those individuals like me who have 5+ events per day with 20+ tasks per day. It helps you focus on the most important tasks and meetings, ensuring you make the most of your time.

## Usage

```
Usage: app.sh [--days <number>] [--debug]
  --days <number>  Process the next <number> of days
  --debug          Enable debug mode
  --killswitch     Exit immediately in the defined position for debugging
  --force          Force the script to run even if the schedule has already been made for the day
  --start-day      Start processing tasks from a specific day (format: YYYY-MM-DD)
  --one-batch      Process all days in one batch, requires --days and --start-day
  --no-scheduling  Skip task scheduling completely, only generate notes
```

## Cronjob

It is recommended to run this script as a cronjob. Here is an example cronjob that runs the script every day at 8:00 AM:

```bash
0 8 * * * SHELL=/bin/bash TZ=Europe/Helsinki LANG=fi_FI.UTF-8 bash /path/to/personal-assistant-cli/app.sh >> /tmp/personal-assistant.log 2>&1
```

The cron job for daily summary to Obsidian:

```bash
58 23 * * * bash /path/to/personal-assistant-cli/personal-assistant-cli/tasks/daily-log.sh >/dev/null 2>&1
```

Todoist backup and sync every 10 minutes:

```bash
*/10 * * * * bash /path/to/personal-assistant-cli/personal-assistant-cli/tasks/todoist-backup-and-sync.sh >/dev/null 2>&1
```

## Features

- Support for macOS and Linux.
- Saves a note of the prioritized tasks and reasoning behind them to Obsidian Vault. Please see: [Setting up a headless Obsidian instance for syncing](https://rolle.design/setting-up-a-headless-obsidian-instance-for-syncing).
- **Sorts through Todoist tasks** for the day.
- **Integrates Google Calendar events** for the day, syncs and times them back to Todoist as actual Todoist tasks.
- Uses **OpenAI GPT-4o-mini** to prioritize tasks and meetings.
- Outputs a **formatted and prioritized list** of tasks in markdown format.
- **Automatically postpones tasks** based on AI recommendations.
- **Schedules task times and durations** based on AI recommendations.
- **Supports multiple days** with the `--days` option, you can pre-schedule the whole week.
- **Gets energy levels** from Oura.
- **Daily log!** - Lists and summarizes completed Todoist tasks to Obsidian with AI feedback
- **Todoist backup and sync to Obsidian** - Syncs all tasks to Obsidian as markdown and completed tasks back to Todoist

## Software and hardware requirements

- Bash shell
- macOS or Linux
- Paid ChatGPT API key
- Todoist API key
- Google Cloud OAuth 2.0 credentials
- Oura ring and API key

## Package requirements

These packages are auto-installed by the script.

- `curl`
- `jq`
- `ggrep` (for macOS users)
- `homebrew` (for macOS users)
- `coreutils` (for macOS users)

## Setup

### Clone the Repository

```bash
git clone https://github.com/ronilaukkarinen/personal-assistant-cli.git
cd personal-assistant-cli
```

### Create a `.env` File

Copy .env.example to .env:

```bash
cp .env.example .env
```

The prompt need to be super accurate. Otherwise this won't work properly. You can add your own background info to bginfo prompts, it should be about who you are, what you do, what you like, what you don't like, what you want to achieve, etc. Work-related prompts should contain the top priorities of your company and your own work schedule. The more accurate the prompts are, the better the results will be.

> **Note**: For help generating your Todoist API key, visit [Todoist Developer Portal](https://developer.todoist.com/).
>
> For creating Google Cloud OAuth 2.0 credentials, follow [this guide](https://github.com/insanum/gcalcli/blob/521bf2a4a41f6830d561dc1993275ca152428596/docs/api-auth.md). In short, go to [Google Cloud Console](https://console.cloud.google.com/) and create credentials for your application from there.

#### Get API token (GOOGLE_API_TOKEN)

Direct the user to Google's OAuth 2.0 URL to authenticate:

```bash
# Open in browser: https://accounts.google.com/o/oauth2/auth?client_id=GOOGLE_CLIENT_ID&redirect_uri=http://localhost&response_type=code&scope=https://www.googleapis.com/auth/calendar.readonly
```

After the user authorizes access, you'll get an authorization code. Use the following curl command to exchange the authorization code to the caps part `AUTHORIZATION_CODE` in the curl command:

```bash
source .env
curl -X POST https://oauth2.googleapis.com/token \
  -d "client_id=${GOOGLE_CLIENT_ID}" \
  -d "client_secret=${GOOGLE_CLIENT_SECRET}" \
  -d "redirect_uri=http://localhost" \
  -d "grant_type=authorization_code" \
  -d "code=AUTHORIZATION_CODE"
```

Add to your "refresh_token" part to the GOOGLE_REFRESH_TOKEN part in your .env.

Add to your env:

```ini
GOOGLE_REFRESH_TOKEN="YOUR_REFRESH_TOKEN"
```

#### Get Google Calendar IDs

Follow these steps to locate the Calendar ID in Google Calendar:

1. **Open Google Calendar Website:**
   - Go to [Google Calendar](https://calendar.google.com/).

2. **Select the Calendar:**
   - In the left sidebar, you'll see a list of calendars. Click the three dots (menu) next to the calendar you want the ID for, then select **Settings and sharing**.

3. **Find the Calendar ID:**
   - In the calendar settings, scroll down to the section labeled **Integrate calendar**.
   - The **Calendar ID** is displayed in this section.
     - For **public calendars**, it will usually be in the format: `xxxxxx@group.calendar.google.com`.
     - For **private calendars** (such as personal calendars), the ID may be your email address: `user@gmail.com`.

### Example Calendar IDs:

- **Public Calendar**: `example123@group.calendar.google.com`
- **Private Calendar**: `user@gmail.com`

You will need this Calendar ID when making API calls to Google Calendar.

Add these to your .env.

### Set up hardcoded prompts in openai.sh

You need to set up your own hardcoded prompts in openai.sh. This is the most important part of the script. The more accurate the prompts are, the better the results will be. The prompt will clarify metadata format of the tasks and events that the AI will use to prioritize your day.

Metadata needs to be in the following format:

```bash
(Metadata: id: "1234567890", priority: "1-4", duration: "0-999", datetime: "YYYY-MM-DDTHH:MM:SS", backlog: "true/false")
```

### Run the Script

You can run the script using the following command:

```bash
bash app.sh
```

### Debugging (Optional)

To view detailed raw responses from OpenAI, use the `--debug` flag:

```bash
bash app.sh --debug
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

- [Roni Laukkarinen](https://github.com/ronilaukkarinen)
