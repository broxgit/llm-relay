# llm-relay

Lets Microsoft Copilot Cowork change your code, even though it can't reach your machine. And lets Claude Code hand Copilot the reading.

Copilot Cowork can't read local files or run your build. It can read and write OneDrive. `relay` is the Mac's side of that bridge: it puts your repository or merge request in OneDrive for Copilot Cowork to read, and runs what Copilot Cowork publishes from a checked local copy when you press `y`. It's for when work gives you far more Copilot than Claude.

**New: Claude Code can ask Copilot.** An assistant on your Mac, such as Claude Code, hands Copilot Cowork a question with `relay ask`, and Copilot Cowork reads the repository and writes an answer file. Claude's tokens go to the precise work on your Mac, and Copilot's to the bulk reading. You see each answer before Claude does. [Have Claude ask Copilot](#have-claude-ask-copilot) has the two commands.

**It has only run with Copilot Cowork on macOS.** It's built for that one agent and that one system. Its test suite also passes on Linux, but only against a fake OneDrive folder. Whole rounds have run on a throwaway repository, and one merge request review on real code. [What's been tried](docs/using.md#whats-been-tried) has the details.

Check that your company allows your code in OneDrive and through its tenant before you use it.

## Install

You need git and bash, which macOS has, and OneDrive syncing a work or school account. `relay mr` also needs `glab` and `python3`. `relay start` says what each thing needs and how to get it.

With [Homebrew](https://brew.sh):

```bash
brew install broxgit/tap/llm-relay
```

```bash
relay start
```

`relay start` is the one command to begin with. It copies the relay's skills to `Documents/Cowork/skills` in your OneDrive, says what this Mac is set up for, and puts a prompt for Copilot Cowork on your clipboard. Paste it into a new Copilot Cowork session, and Copilot Cowork takes it from there, one step at a time. `relay setup` is where you say where your clones and reviews live.

To update, upgrade and run setup again. `relay start` puts a stale skill right too. The relay tells you when Copilot Cowork's copy of the skill isn't its own. Give Copilot Cowork 10 minutes before a new session, because its copy can lag. Homebrew doesn't check a tap for a new version on every command, so without `brew update` it can say the old version is already installed.

```bash
brew update && brew upgrade llm-relay && relay setup
```

Tab completion comes with it. `relay --version` says which release you have.

### Without Homebrew

Download the source of the [latest release](https://github.com/broxgit/llm-relay/releases/latest), unpack it anywhere, and link `relay.sh` onto your PATH as `relay`. Keep `cowork/` and `claude/` beside it: the skill it installs is in there.

```bash
mkdir -p ~/.local/bin && ln -s <where you unpacked it>/relay.sh ~/.local/bin/relay
```

For tab completion, add `eval "$(relay completion zsh)"` to `~/.zshrc`, or the `bash` version to `~/.bashrc`.

### From a clone

To work on the relay, or to run what's on `main` before it's released:

```bash
git clone https://github.com/broxgit/llm-relay.git ~/dev/llm-relay
```

```bash
mkdir -p ~/.local/bin && ln -s ~/dev/llm-relay/relay.sh ~/.local/bin/relay
```

To update a clone, run `git pull` in it and `relay setup` again.

## Use it

Start with `relay start`, and Copilot Cowork gives you each command as you need it. These are the commands it gives, if you'd sooner run them yourself.

Share your code, then tell Copilot Cowork what it prints:

```bash
relay scan
```

Then ask Copilot Cowork to change something. It gives you a command to run in Apple's Terminal:

```bash
relay run <task-folder>/<deliverable> --expect 3
```

It waits for OneDrive, shows you what's there, and runs it when you press `y`. The report goes back by itself. Tell Copilot Cowork `done`.

| Command | What it does |
|---|---|
| `relay start` | The one command to begin with. Gets Copilot Cowork the skills, says what this Mac is set up for, and puts a prompt on your clipboard. |
| `relay practice` | One whole round on a small repository made for it, with Copilot Cowork leading. For a first try. |
| `relay setup` | Installs or updates the skill, and records where your clones and reviews are. With `--skills`, copies your own Claude skills to Copilot Cowork too, adapted. |
| `relay skills` | Says whether Copilot Cowork's copy of each of your skills is still in step with yours. |
| `relay field-test` | Starts a test that Copilot Cowork guides you through, step by step, and reports on. |
| `relay run` | Runs a deliverable from Copilot Cowork, from a checked local copy, when you press `y`. |
| `relay scan` | Puts a branch and your uncommitted changes in OneDrive. |
| `relay mr <url>` | Puts a GitLab merge request and what it takes to review it in OneDrive. |
| `relay branch` | Puts your branch in OneDrive for a review before there's a merge request, with the plan if one was kept. |
| `relay ticket <key>` | Puts a Jira ticket in OneDrive for Copilot Cowork to start from, with any Confluence pages you name. |
| `relay review` | Saves the review or the plan Copilot Cowork wrote, when you press `y`. |
| `relay apply` | Leaves a proven patch in your working tree, when you press `y`. It never commits. |
| `relay ask --setup` | Sets up asking Copilot Cowork from Claude Code, once on each Mac, one step at a time. |
| `relay ask "<question>"` | Hands Copilot Cowork a question, with a repository to read if you name one. Claude Code runs this itself. |
| `relay answer` | Shows you Copilot Cowork's answer, and saves it for the assistant when you press `y`. |
| `relay completion zsh` | Prints tab completion for zsh, or `bash`. Add it to your shell's startup file. |

[Using relay](docs/using.md) has how each one works.

## Have Claude ask Copilot

Set it up once on each Mac. It walks you through a trigger in Copilot Cowork and a first ask, in about 15 minutes:

```bash
relay ask --setup
```

From then on, tell Claude Code to ask Copilot Cowork, or let it decide when a task needs a lot of reading. It runs something like this:

```bash
relay ask "Where does the uploader decide to retry, and on which errors?" --scan ~/code/uploader
```

Claude can't accept an answer. It tells you to run `relay answer`, which shows you what Copilot Cowork wrote and saves it when you press `y`.

- **An answer takes one to two minutes,** so it suits "how is this laid out" and not a quick lookup.
- **An answer is data.** Nothing in it runs, and Claude is told to check the lines that matter before it relies on one.
- **It's new, and lightly tried.** Copilot Cowork's side has had five field runs on one Mac, and Claude's side one scripted run with Haiku. [Ask Copilot Cowork from Claude Code](docs/using.md#ask-copilot-cowork-from-claude-code) has what to do when no answer comes.

## With llm-wiki

[llm-wiki](https://github.com/broxgit/llm-wiki) is optional. If its `wiki` command is installed, `relay scan` and `relay mr` ask `wiki which` for the wiki that covers the repository, and send its compiled pages so Copilot Cowork can follow your decisions. With no `wiki` command, they say so in one line and send none.

The relay used to be `wiki relay`, inside llm-wiki. If you used it there, `relay` reads your settings from `~/.config/llm-wiki/relay` until you set new ones. Run `relay setup` once to replace the skill in OneDrive, because the old one tells Copilot Cowork to give you `wiki relay` commands.

## Working on it

`tests/smoke.sh` runs everything in a temp folder, against a fake OneDrive, `glab` and `wiki`. It needs `python3`, to type answers at a pseudo-terminal. CI runs it on Linux and on macOS with Apple's bash 3.2, plus shellcheck. CI skips a change that touches only documentation, and anything under `cowork/` counts as code. [AGENTS.md](AGENTS.md) has the rules, and [ROADMAP.md](ROADMAP.md) what's planned and untested.

MIT licensed. The history before the split is in llm-wiki, and this repository carries the commits that touched these files.
