# Using relay

Cowork can't reach your files or run your build, but it can still change your code. It publishes a folder to OneDrive, you run one command, and the report goes back. Check that your company allows your code in OneDrive and through its tenant.

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

To see where things stand, without changing anything:

```bash
relay skills
```

A skill can hold rules you wouldn't want in the company's cloud, so check what your company allows first. Give Cowork 10 minutes and a new session to pick up a changed copy. A review says which copy it used, and `relay review` warns if it was an older one.

## Share your code

Run this in the repository, then tell Cowork what it prints:

```bash
relay scan
```

It puts the current branch and your uncommitted changes in OneDrive, at `Documents/Cowork/relay/scans`, so you don't have to attach anything. That includes the branch's whole history. Untracked files stay out.

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

`relay apply` then applies only the attempt that passed. It takes that from the report, and only if the report in OneDrive is the same file your Mac kept in `~/pair-run-reports`. If no run has passed, it applies nothing.

This needs the skill from this version, so run `relay setup` after updating.

## Review a merge request

If you keep a review skill, Cowork can follow it, using what this command sends in place of `glab` and your clones. Your skill only needs to add the rules Cowork can't otherwise see, such as ones in your agent's memory. Run it in any terminal:

```bash
relay mr <url> --also ~/dev/some-service --also ~/dev/deployments/my-service
```

- Cowork also looks in your Teams chats, email and SharePoint for the discussion behind a change, and says what it found. That's Cowork's own reach: the relay sends none of it.
- It sends the merge request's discussions and diff, its source and target branches, your own Go libraries at the versions `go.mod` pins, your earlier review, and the wiki if there is one. It only fetches in your clone, and puts a prompt for Cowork on your clipboard.
- `--also` sends another repository at origin's default branch, or only one folder of it, and `PATH@BRANCH` names a branch. Use it as many times as you like.
- For a Go repository, it asks whether to run `go build`, `go vet`, `go test` and `go mod tidy -diff` first, and sends the results. They run on a temporary copy of the branch with git hooks off, so your clone and uncommitted work stay out of it, but the branch's code does run on your Mac. Each check stops after 10 minutes. `--checks` and `--no-checks` answer for you. `--checks` is the one place the relay runs code without asking, so it's yours to add. Cowork is told never to give you a command with it, so don't run one that has it.
- It reviews what's pushed, and warns if your local branch has commits the merge request doesn't.
- Cowork publishes the review, and gives you `relay review`. It shows you the file and its Coverage section, which says what Cowork read and skipped, and saves it where you keep your reviews when you press `y`. Your earlier copy is kept beside it as `.previous`. Run that one in Apple's Terminal.
- For a fix you've proven, `relay apply` leaves its patches in your working tree when you press `y`, and never commits.

It's built for GitLab and Go. Cowork still can't see production data, and it reads other services only if it asks or you add `--also`.

## What's been tried

- Four test sessions with Cowork, on a throwaway repository, led to this. On 2026-11-04, whole rounds ran from Apple's Terminal with nothing attached and no Always Keep: a fresh publish, a real failure, its fix, and pressing `n`. Scans worked at up to 50 MB.
- A merge request review ran once on a real merge request, on 2026-11-04, before the checks and the Coverage section were added. In that review, a run on the Mac proved a build failure that Cowork had only rated Low from reading the code.
- All of that ran as `wiki relay`, inside llm-wiki. The standalone `relay` command has only run in its smoke tests, against a fake OneDrive folder.
