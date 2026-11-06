# Using relay

Cowork can't reach your files or run your build, but it can still change your code. It publishes a folder to OneDrive, you run one command, and the report goes back. Check that your company allows your code in OneDrive and through its tenant.

## Start here

```bash
relay start
```

It's the only command you need to know to begin, and it's worth running at the start of any session.

- **It gets Cowork the relay's skills.** If Cowork has none, or an older relay's after an upgrade, it installs them and tells you when to start, by the clock, because Cowork can take 10 minutes to see a new skill.
- **It says what this Mac is set up for.** Each thing the relay does is listed as ready, or with the tool it needs and how to get it. A review needs `glab`, for one.
- **It puts a prompt for Cowork on your clipboard.** Paste it into a new Cowork session. Cowork reads a short note about your setup, with no paths in it, checks that its copy of the skill is current, and asks what you're working on.

From there Cowork gives you one step at a time, each in the same block: the command, what to expect if anything would surprise you, and what to tell it afterwards. If its steps drift from that, send it: `Use the YOUR TURN block format.`

It asks you nothing. Where your clones and reviews live is set with `relay setup`, below.

## Setup

The [README](../README.md#install) has how to install it. With OneDrive syncing, in a terminal:

```bash
relay setup
```

It copies a skill called `remote-pair-run` to `Documents/Cowork/skills` in your work OneDrive, and Cowork finds it when a new session starts. Run it again to update the skill. If you have several work OneDrive folders, name one with `--dir`, before or after `setup`. If you use it for Go, attaching the Linux Go tarball from [go.dev/dl](https://go.dev/dl/) lets Cowork compile in its own sandbox first.

The first time, it asks where your clones and reviews live. `--clones` and `--reviews` answer for you. They're kept in `~/.config/llm-relay/settings`. A setting that file doesn't have comes from `~/.config/llm-wiki/relay`, where they lived when the relay was part of llm-wiki. That old file is never changed.

After you update the skill, a new Cowork session can still load the old copy for several minutes, so give it 10.

## Your own skills in Cowork

Cowork reads skills in the same shape Claude does, so it can use yours. Name the ones you want it to have:

```bash
relay setup --skills mr-review:simple-english
```

- **What it gets is a copy, adapted.** Each copy is your skill with a note on top. The note tells Cowork what to do where your skill expects Claude's tools: use what the relay sent in place of `glab` and your clones, skip anything that posts, and ask for what it can't see. It also lists the tools your skill names that Cowork doesn't have. The rest is your skill's text, unchanged.
- **Your skill stays the only thing you edit.** The copy is made again by `relay setup`, `relay scan` or `relay mr` whenever your skill has changed, and they say so when they do. For notes that only apply in Cowork, put a `COWORK.md` beside the skill's `SKILL.md`, and its text goes into the note.
- **It goes one way.** If Cowork changes its copy in OneDrive, nothing comes back to your Mac, and nothing overwrites the change unasked. `relay setup` shows you the difference and asks before it replaces the copy.
- **Only what you name.** `--skills none` stops copying them and removes the copies. `--skills-from` says where your skills live, if it isn't `~/.claude/skills`. A skill of the same name that you put in Cowork's folder yourself is never touched. To hand such a skill over to the relay, move anything that's only for Cowork into a `COWORK.md` beside your skill, move the folder out of Cowork's skills folder, and run `relay setup` again.

If `relay skills` or `relay setup` says a terminal app can't read Cowork's copy, the copy is left as it is. macOS can refuse one terminal app a file in OneDrive that another reads, so try Apple's Terminal.

To see where things stand, without changing anything:

```bash
relay skills
```

A skill can hold rules you wouldn't want in the company's cloud, so check what your company allows first. Give Cowork 10 minutes and a new session to pick up a changed copy. A review says which copy it used, and `relay review` warns if it was an older one.

## Share your code

Run this in the repository, then tell Cowork what it prints. At a terminal that line is also put on your clipboard, and scans within two minutes of each other add up there, so you can paste once for several:

```bash
relay scan
```

It puts the current branch and your uncommitted changes in OneDrive, at `Documents/Cowork/relay/scans`, so you don't have to attach anything. That includes the branch's whole history. Untracked files stay out.

**It looks for secrets first.** Before `relay scan` or `relay mr` sends code, it looks in the files for private keys, access tokens, lines in settings files that set a password or key, and files named like keys or credentials. If it finds any, it lists where they are, without printing them, and asks before it sends. That question needs a terminal, and no flag answers it for you. Say no, and nothing is sent.

It goes by shape, so it can miss a secret, and it can flag something harmless. It reads the files at the commit being sent, and your uncommitted changes to them, and not the history, which goes too. So a repository that holds credentials, or ever did, is one to think about before you scan it, whatever the check says.

A scan is named after the repository's folder. When two repositories share a folder name, as a service's code and its deployment folder can, the second takes its parent folder's name in front, and the command says so. Neither replaces the other.

To share a different branch without leaving yours, add `--branch`. It fetches, and sends that branch as origin has it, or your local copy if origin doesn't have it. Your checkout isn't touched, and uncommitted changes stay out:

```bash
relay scan --branch master
```

If you use [llm-wiki](https://github.com/broxgit/llm-wiki) and a wiki covers the repository, its `index.md` and compiled pages go too, and the command says so. Cowork reads them before it plans, so you don't have to repeat your rules. It gets a read-only copy, as of that scan, and can't save notes. Raw notes, other wikis and the shared wiki stay on your machine. Check that your company allows that wiki's content in OneDrive and through its tenant, or add `--no-wiki`. The relay finds the wiki with `wiki which`, run from the repository's folder. To use one collection of wikis instead, set `WIKIS_DIR` for the command. With no `wiki` command installed, it says so in one line and sends no wiki.

## A round

Ask Cowork to change something. Each round goes like this:

1. It gives you one command, `relay run` with a version number. The command waits for OneDrive to catch up, and copies the files out once every one matches what Cowork published.
2. It shows you what's there. Press `y` to run it, `v` to read the files first, or `n` to stop. The answer has to be typed at the terminal: it can't be piped in, and no setting answers for you. It runs on your machine, so read what Cowork says it will change. The run compares the new output with the old, and restores what it touched. It never commits or pushes.
3. The report goes to OneDrive by itself, only if a run happened, and a copy stays in `~/pair-run-reports`. You see all of it in your terminal as it runs. Tell Cowork `done`, and it reads the report.

Run `relay run` in Apple's Terminal. macOS can refuse other terminal apps on OneDrive files that aren't downloaded yet: in one test it refused iTerm with `Operation not permitted`, with no pop-up, and let Terminal read the same files. It doesn't always happen, and why isn't known. The command says so if it does.

If OneDrive never catches up, the command gives up after 10 minutes, prints what your Mac sees for each file, and sends nothing. Paste that output to Cowork. If your OneDrive allows it, in Finder, right-click the task's `output` folder, choose **Always Keep on This Device**, and run it again.

## Several attempts in one round

When Cowork can see two or three plausible fixes, it can put them all in one deliverable. You still read it and press `y` once. The run tries them in order, each in a fresh copy of the code with git hooks off, and stops at the first that passes. Your checkout isn't touched, and the report says which attempt passed and why the others failed.

`relay apply` then applies only the attempt that passed. It takes that from the report your Mac kept in `~/pair-run-reports` when it last ran exactly those files, and never from OneDrive. If no run has passed, or the files have changed since the run, it applies nothing and says to run it first.

This needs the skill from this version, so run `relay setup` after updating.

## Review a merge request

If you keep a review skill, Cowork can follow it, using what this command sends in place of `glab` and your clones. Your skill only needs to add the rules Cowork can't otherwise see, such as ones in your agent's memory. Run it in any terminal:

```bash
relay mr <url> --also ~/dev/some-service --also ~/dev/deployments/my-service
```

- Cowork also looks in your Teams chats, email and SharePoint for the discussion behind a change, and says what it found. That's Cowork's own reach: the relay sends none of it.
- It sends the merge request's discussions and diff, its source and target branches, your own Go libraries at the versions `go.mod` pins, your earlier review, and the wiki if there is one. It only fetches in your clone, and puts a prompt for Cowork on your clipboard.
- `--also` sends another repository at origin's default branch, or only one folder of it, and `PATH@BRANCH` names a branch. Use it as many times as you like.
- The relay finds your clone in the folder you're in, or under the folders `relay setup --clones` names. If it's somewhere else, name it once with `--repo` and the relay remembers it.
- For a Go repository, it asks whether to run `go build`, `go vet`, `go test` and `go mod tidy -diff` first, and sends the results. They run on a temporary copy of the branch with git hooks off, so your clone and uncommitted work stay out of it, but the branch's code does run on your Mac. Each check stops after 10 minutes. `--checks` and `--no-checks` answer for you. `--checks` is the one place the relay runs code without asking, so it's yours to add. Cowork is told never to give you a command with it, so don't run one that has it.
- It reviews what's pushed, and warns if your local branch has commits the merge request doesn't.
- Cowork publishes the review, and gives you `relay review`. It shows you the file and its Coverage section, which says what Cowork read and skipped, and saves it where you keep your reviews when you press `y`. Your earlier copy is kept beside it as `.previous`. Run that one in Apple's Terminal.
- For a fix you've proven, `relay apply` leaves its patches in your working tree when you press `y`, and never commits.

It's built for GitLab and Go. Cowork still can't see production data, and it reads other services only if it asks or you add `--also`.

## Have Cowork walk you through a test

To check that everything works on your machine, or to help improve the relay, let Cowork run the test:

```bash
relay field-test
```

It does three things:

- **Makes a small repository at `~/relay-field-test`** for the test to change, so nothing of yours is at risk.
- **Puts a short note about your setup in OneDrive.** It has the relay's version, your system and terminal app, and whether Cowork has the relay's skills. It holds no paths, names or repositories of yours.
- **Puts a prompt on your clipboard.** Paste it into a new Cowork session.

Cowork then guides you with the `relay-field-test` skill, which `relay setup` installs. First it checks that its own copy of the skills is this relay's, and stops if it isn't. Then it gives you one step at a time, in a block you can't miss:

- **DO THIS NOW:** one command, and which keys to press.
- **WATCH FOR:** what should happen, and any macOS pop-up.
- **SCREENSHOT:** what to capture, said before the moment.
- **DON'T:** the easy mistake at that step.
- **THEN TELL ME:** exactly what to send back.

When it needs nothing from you, its message starts with "NOTHING FOR YOU TO DO YET". If its steps get hard to follow, send it: `Use the YOUR TURN block format.`

It asks how long you have. The short version is about 30 minutes. Use Apple's Terminal, and keep to one tab.

At the end it writes a report against criteria that are fixed in the skill: what passed and failed, how long things took, how much you had to do by hand, and what in the skills was unclear. It's told to leave your company's names, code and tickets out of it. The report comes back like a review:

```bash
relay review <task-folder>/<deliverable> --expect 1
```

Press `v` to read it, and `y` to save it under `field-test` where you keep reviews. Read it over before you send it to anyone.

Afterwards, this removes the test repository and what the test left in OneDrive:

```bash
relay field-test --clean
```

[The session walkthrough](../design-and-decisions/work-mac-session.md) has the same steps written out, if you'd sooner do it by hand.

## What's been tried

- Four test sessions with Cowork, on a throwaway repository, led to this. On 2026-11-04, whole rounds ran from Apple's Terminal with nothing attached and no Always Keep: a fresh publish, a real failure, its fix, and pressing `n`. Scans worked at up to 50 MB.
- A merge request review ran once on a real merge request, on 2026-11-04, before the checks and the Coverage section were added. In that review, a run on the Mac proved a build failure that Cowork had only rated Low from reading the code.
- All of that ran as `wiki relay`, inside llm-wiki. The standalone `relay` command has only run in its smoke tests, against a fake OneDrive folder.
