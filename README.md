# llm-relay

Lets Microsoft Copilot Cowork change your code, even though it can't reach your machine.

Cowork can't read local files or run your build. It can read and write OneDrive. `relay` is the Mac's side of that bridge: it puts your repository or merge request in OneDrive for Cowork to read, and runs what Cowork publishes from a checked local copy when you press `y`. It's for when work gives you far more Copilot than Claude.

**It has only run with Copilot Cowork on macOS.** It's built for that one agent and that one system. Its test suite also passes on Linux, but only against a fake OneDrive folder. Whole rounds have run on a throwaway repository, and one merge request review on real code. [What's been tried](docs/using.md#whats-been-tried) has the details.

Check that your company allows your code in OneDrive and through its tenant before you use it.

## Install

You need git and bash, which macOS has, and OneDrive syncing a work or school account. `relay mr` also needs `glab` and `python3`.

With [Homebrew](https://brew.sh):

```bash
brew install broxgit/tap/llm-relay
```

```bash
relay setup
```

`relay setup` copies a skill called `remote-pair-run` to `Documents/Cowork/skills` in your OneDrive, and asks where your clones and reviews live. Cowork finds the skill when a new session starts.

To update, upgrade and run setup again. The relay tells you when Cowork's copy of the skill isn't its own. Give Cowork 10 minutes before a new session, because its copy can lag. Homebrew doesn't check a tap for a new version on every command, so without `brew update` it can say the old version is already installed.

```bash
brew update && brew upgrade llm-relay && relay setup
```

Tab completion comes with it. `relay --version` says which release you have.

### Without Homebrew

Download the source of the [latest release](https://github.com/broxgit/llm-relay/releases/latest), unpack it anywhere, and link `relay.sh` onto your PATH as `relay`. Keep `cowork/` beside it: the skill it installs is in there.

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

Share your code, then tell Cowork what it prints:

```bash
relay scan
```

Then ask Cowork to change something. It gives you a command to run in Apple's Terminal:

```bash
relay run <task-folder>/<deliverable> --expect 3
```

It waits for OneDrive, shows you what's there, and runs it when you press `y`. The report goes back by itself. Tell Cowork `done`.

| Command | What it does |
|---|---|
| `relay setup` | Installs or updates the skill, and records where your clones and reviews are. With `--skills`, copies your own Claude skills to Cowork too, adapted. |
| `relay skills` | Says whether Cowork's copy of each of your skills is still in step with yours. |
| `relay field-test` | Starts a test that Cowork guides you through, step by step, and reports on. |
| `relay run` | Runs a deliverable from Cowork, from a checked local copy, when you press `y`. |
| `relay scan` | Puts a branch and your uncommitted changes in OneDrive. |
| `relay mr <url>` | Puts a GitLab merge request and what it takes to review it in OneDrive. |
| `relay review` | Saves the review Cowork wrote, when you press `y`. |
| `relay apply` | Leaves a proven patch in your working tree, when you press `y`. It never commits. |

[Using relay](docs/using.md) has how each one works.

## With llm-wiki

[llm-wiki](https://github.com/broxgit/llm-wiki) is optional. If its `wiki` command is installed, `relay scan` and `relay mr` ask `wiki which` for the wiki that covers the repository, and send its compiled pages so Cowork can follow your decisions. With no `wiki` command, they say so in one line and send none.

The relay used to be `wiki relay`, inside llm-wiki. If you used it there, `relay` reads your settings from `~/.config/llm-wiki/relay` until you set new ones. Run `relay setup` once to replace the skill in OneDrive, because the old one tells Cowork to give you `wiki relay` commands.

## Working on it

`tests/smoke.sh` runs everything in a temp folder, against a fake OneDrive, `glab` and `wiki`. It needs `python3`, to type answers at a pseudo-terminal. CI runs it on Linux and on macOS with Apple's bash 3.2, plus shellcheck. CI skips a change that touches only documentation, and anything under `cowork/` counts as code. [AGENTS.md](AGENTS.md) has the rules, and [ROADMAP.md](ROADMAP.md) what's planned and untested.

MIT licensed. The history before the split is in llm-wiki, and this repository carries the commits that touched these files.
