# Task Prioritization Tool

> [!NOTE] 
> **Please note!** This project uses hardcoded Finnish language strings and is 100% meant for my personal usage. The prompt is in Finnish, the tasks are in Finnish, and the output is in Finnish. If you want to use this, you need to modify the script to your own language and needs.

This is a Bash-based tool that prioritizes your daily tasks using OpenAI's GPT-4 model. It integrates tasks from Todoist and events from Google Calendar to create a comprehensive view of your day, allowing you to make informed decisions about what to prioritize.

## Features

- Support for macOS and Linux.
- **Fetches Todoist tasks** for the current day.
- **Integrates Google Calendar events** for the day.
- Uses **OpenAI GPT-4** to prioritize tasks and meetings.
- Outputs a **formatted and prioritized list** of tasks.
- Supports a `--debug` flag to show raw OpenAI responses for troubleshooting.

## Requirements

- Bash shell
- `curl`
- `jq`
- `gcalcli` (for Google Calendar integration)

## Setup

### Step 1: Clone the Repository

```bash
git clone https://github.com/your-username/task-prioritization-tool.git
cd task-prioritization-tool
```

### Step 2: Install Dependencies

Ensure the following tools are installed:

1. **`jq`**: Used for parsing JSON data.

   ```bash
   sudo apt-get install jq
   ```

2. **`gcalcli`**: Used for Google Calendar integration.

   ```bash
   sudo apt-get install gcalcli
   ```

3. **`curl`**: For making HTTP requests.

   ```bash
   sudo apt-get install curl
   ```

### Step 3: Create a `.env` File

Create a `.env` file in the root directory of the project with the following variables:

```bash
TODOIST_API_KEY="your_todoist_api_key"
OPENAI_API_KEY="your_openai_api_key"
GOOGLE_CLIENT_ID="your_google_client_id"
GOOGLE_CLIENT_SECRET="your_google_client_secret"
GOOGLE_API_TOKEN="your_google_api_token"
WORK_PROMPT_BGINFO="your_background_info_here"
LEISURE_PROMPT_BGINFO="your_background_info_here"
WORK_PROMPT="your_instructions_on_which_format_to_write_notes"
LEISURE_PROMPT="your_instructions_on_which_format_to_write_notes"
WORK_CALENDAR_ID="your_work_calendar_id"
FAMILY_CALENDAR_ID="your_family_calendar_id"
TRAINING_CALENDAR_ID="your_training_calendar_id"
```

The prompt need to be super accurate. Otherwise this won't work properly.

**Prompt Example:** "I am a business-oriented technology leader, entrepreneur and founder of a 50-person company. Our company is a [YOUR COMPANY AREA OF EXPERTISER] and our main products are [YOUR PRODUCTS HERE]. We do [YOUR SERVICES HERE] and so on. I'm super busy and my to-do list is often full. In addition to me, our company has [YOUR PERSONNEL HERE]. A job for you: What are the most important tasks I should do today, top 5? Also suggest tasks to postpone to a later date. Format your list in markdown format, remembering to have clear spaces after the headings and estimate a time for each task. My working hours are about 8h per day, but I can stretch. Take into account the day's meetings (1h per event on average) and the scope of the task (if sub-tasks, the task will be more extensive). Note, don't make up your own or more, but respect the original list. Please provide a complete list with original tasks, only sorted and justified. Do not omit any task from the compilation. Here is the actual list of today's tasks and meetings on which to base your conclusion:"

- Replace `your_todoist_api_key` with your Todoist API key.
- Replace `your_openai_api_key` with your OpenAI API key.
- Replace `your_google_client_id` and `your_google_client_secret` with your Google Cloud OAuth 2.0 credentials.

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
   - In the left sidebar, you’ll see a list of calendars. Click the three dots (menu) next to the calendar you want the ID for, then select **Settings and sharing**.

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

### Step 4: Authenticate Google Calendar (`gcalcli`)

Run the following command to authenticate Google Calendar using `gcalcli`:

```bash
gcalcli list
```

This will open a browser window asking for your Google account credentials and permissions to access your calendar. Once authenticated, `gcalcli` will store your credentials locally.

### Step 5: Run the Script

You can run the script using the following command:

```bash
./prioritize_tasks.sh
```

### Step 6: Debugging (Optional)

To view detailed raw responses from OpenAI, use the `--debug` flag:

```bash
./prioritize_tasks.sh --debug
```

## Example Output

When run successfully, the script outputs a formatted list of prioritized tasks based on Todoist tasks and Google Calendar events:

```
Haetaan tämänpäiväiset Todoist-tehtävät...
Tämänpäiväiset tehtävät:
- Review project roadmap
- Code review for team

Haetaan tämänpäiväiset Google Calendar -tapahtumat...
Tämänpäiväiset kalenteritapahtumat:
- 10:00 - Project Kickoff Meeting
- 14:00 - Client Discussion

Priorisoidaan tehtävät OpenAI:n avulla...
Priorisoidut tehtävät ja asiat:
**1.** Project Kickoff Meeting at 10:00
**2.** Code review for team
**3.** Review project roadmap
**4.** Client Discussion at 14:00
```

## Troubleshooting

### Issue: `gcalcli` Authentication Fails

If `gcalcli` fails to authenticate, try re-running the authentication step:

```bash
gcalcli list
```

Alternatively, you can delete the local `gcalcli` credentials and try again:

```bash
rm -rf ~/.gcalcli_oauth
gcalcli list
```

### Issue: `OPENAI_API_KEY` Not Found

Check that your `.env` file contains the correct OpenAI API key:

```bash
cat .env
```

Ensure the line for `OPENAI_API_KEY` is correctly formatted and doesn't have extra spaces or newlines.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

If you have ideas for improvements or want to fix a bug, feel free to submit a pull request or open an issue!

## Author

- [Roni Laukkarinen](https://github.com/ronilaukkarinen)
