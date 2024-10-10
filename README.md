# Task Prioritization Tool

> [!NOTE] Please note!
> This project uses hardcoded Finnish language strings and is 100% meant for my personal usage. The prompt is in Finnish, the tasks are in Finnish, and the output is in Finnish. If you want to use this, you need to modify the script to your own language and needs.

This is a Bash-based tool that prioritizes your daily tasks using OpenAI's GPT-4 model. It integrates tasks from Todoist and events from Google Calendar to create a comprehensive view of your day, allowing you to make informed decisions about what to prioritize.

## Features

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
```

- Replace `your_todoist_api_key` with your Todoist API key.
- Replace `your_openai_api_key` with your OpenAI API key.
- Replace `your_google_client_id` and `your_google_client_secret` with your Google Cloud OAuth 2.0 credentials.

> **Note**: For help generating your Todoist API key, visit [Todoist Developer Portal](https://developer.todoist.com/).
>
> For creating Google Cloud OAuth 2.0 credentials, follow [this guide](https://github.com/insanum/gcalcli/blob/521bf2a4a41f6830d561dc1993275ca152428596/docs/api-auth.md).

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
