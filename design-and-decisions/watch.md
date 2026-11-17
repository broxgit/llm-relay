# `relay watch`

**Status: adopted on 2026-11-17, and revised the same day after a second review. The core of the usual mode is built, at 0.2.30: requests, replies, the keypress and the chain. What changed since the last yes, the tally and the unattended mode are not. The usual mode keeps the rule that nothing from the cloud runs or lands on the Mac without a keypress there. The unattended mode, which Brock asked for, is a named exception to that rule. Every decision is made, and they are listed at the end.**

Brock asked for an "auto" mode, so that Copilot Cowork could do its work without him running a scan, a run and an apply for every change. This note has two modes:

- **The usual mode** removes everything except one keypress a round.
- **The unattended mode** removes that too, for a limited time, and is hard to turn on by design.

## Why

One round of a change today, from Copilot publishing a deliverable to reading its report:

1. Copilot publishes, reads the manifest back, and hands over a `relay run` command in a YOUR TURN block.
2. Brock copies the command.
3. He switches to Apple's Terminal and pastes it.
4. He waits for OneDrive.
5. He presses **v**, **q** and **y**.
6. He switches back to Copilot and types "done".
7. Copilot finds the newest report and reads it.

A fresh `relay scan` after his own edits is another round of steps 2, 3 and 6, and so is `relay apply` at the end. The keypress in step 5 is the only step that protects anything. The rest is carrying text between two windows.

With `relay watch` running, a change that passes costs one **y**: it runs, is applied, and is scanned again, and Copilot reads the result itself. A scan costs nothing.

## What stays as it is, in the usual mode

- **The keypress.** Anything that runs or lands asks at the terminal first. No flag, list of trusted repositories or timer answers for the user.
- **The secrets check.** A scan sends with no question only when the relay already does that today: at a terminal, for a repository where Brock said yes before, when what the check finds hasn't changed. Anything new asks, as now. This holds in the unattended mode too.
- **What Copilot writes is data.** A request picks from a fixed list. It can't hold a command, a path, a flag or a repository the watch wasn't started with.

## How it works

### Starting

```bash
relay watch ~/code/thing [~/code/other]...
```

It needs a terminal, and is meant to stay open in Apple's Terminal for a working session. The repositories named are the only ones it will scan or apply to. It:

1. Scans each repository, as `relay scan` would, since that's the first thing a session needs anyway.
2. Writes `Documents/Cowork/relay/watch/note.txt`: a new session id, the relay's version, the repositories by name, when it started, and where requests and replies go.
3. Puts a prompt on the clipboard, for Copilot: "relay watch is running. Read Documents/Cowork/relay/watch/note.txt, with nothing attached."
4. Waits for requests.

### Requests

Copilot asks for something by writing the next numbered file, `Documents/Cowork/relay/watch/<session>/requests/<n>.txt`:

```
LLM-RELAY REQUEST
session: 20261117-140501
n: 4
do: run
deliverable: fix-retry/retry-2
expect: 3
then: apply
repository: thing
```

| `do:` | The other lines | What the relay does |
|---|---|---|
| `scan` | `repository:` one of the session's, by name. `untracked: yes` if wanted | `relay scan` of it. No keypress, as decided |
| `run` | `deliverable:`, `expect:`. With `then: apply` and `repository:`, a pass is applied and the repository scanned again | `relay run`, with the keypress |
| `apply` | `deliverable:`, `expect:`, `repository:` | `relay apply`, with the keypress, then a scan |
| `review` | `deliverable:`, `expect:` | `relay review`, with the keypress |
| `stop` | none | Ends the watch |

A request with any other line, a `do:` not in the table, a repository not in the session, or another session's id is refused. The terminal says so in a line, and the reply says why.

Requests never fetch a ticket or a merge request. Those commands run with Brock's sign-ins to Jira and GitLab, so a planted instruction could use a request to pull anything he can read into OneDrive.

The relay reads `<n>.txt` by its name and never lists the folder, as `relay answer` does. In the wake tests, a listing of a new folder once came back empty while its files could be read by name. It looks three numbers ahead, so one skipped number doesn't stall the session. Requests are done one at a time, in order, and a number already done is skipped.

### Seen, then a reply

As soon as the relay reads a request, it writes `replies/<n>.seen`, one line saying what it is about to do or ask. Copilot can then tell a watch that is waiting for a keypress from one that has died.

When the request is finished, it writes `replies/<n>.txt`:

- what it did: `done`, `refused`, or `the user said no`;
- where the result is, such as the report's path or the scan's note;
- the next request number, so a Copilot whose working area reset can't lose count;
- for each repository, whether it has changed since its last scan, so Copilot asks for a fresh one before it patches stale code.

### Copilot waits for the reply itself

After writing a request, Copilot stays in the same turn and lists the session's `replies` folder every 20 seconds, with a `sleep 20` in its sandbox between tries, for up to 10 minutes. When `<n>.txt` is in the listing, it reads it and carries on, and nobody types "done". If it doesn't come, Copilot ends its turn with one line: what the `.seen` file says the terminal is waiting for, and "tell me done".

It lists the folder, and never reads the reply's path until the listing shows it. A test on 2026-11-17 showed why:

- Copilot kept one turn going for 163 seconds and then 488 seconds, with a real `sleep 20` between tries. Nothing ended either turn early, and nothing asked for approval.
- Reading a path that doesn't exist yet stopped after three tries. Copilot's own tooling refuses a call that has failed three times in a row with the same arguments, and kept refusing after the file existed.
- Listing the folder isn't a failure, so it can repeat: 18 listings in a row worked, and the last showed the file 5 seconds after it was saved.
- That is one session, with two waits. Waits longer than about 8 minutes weren't tried.

So the relay makes the `requests` and `replies` folders when the watch starts, each with a small file in it, so that Copilot has a folder to list from its first request. The note gives Copilot both folders' paths.

### One keypress for the chain

For a `run` with `then: apply`, the question is:

```
Run it, and apply it if it passes? [y]es to both, [r]un only, [v]iew, [n]o:
```

**y** runs it, and on a PASS applies the same patches Brock was just shown, then scans the repository, and replies with the report and the new scan. A FAIL applies nothing. Nothing is ever committed. Decided on 2026-11-17: one **y** may cover both.

### What changed since the last yes

The relay keeps the copy of each deliverable Brock last said **y** to. For a later version it shows what differs, such as `run.sh: 3 lines changed` and `fix.patch: +12 −4`, and **v** opens that difference first, with the whole files after it. A first version shows everything, as now. Questions will come faster with a watch, and this keeps reading before **y** quick enough to keep doing.

### Asking for the keypress

The relay rings the terminal's bell and shows a macOS notification, "relay: run fix-retry/retry-2?", because Brock may be in another window. While it waits, later requests wait behind it.

### The session's tally

The watch sees every round, so it keeps the times: how long each request waited on OneDrive, on the keypress, and on the run. The terminal shows the session as one timeline in the house style, a stage for each request, and a summary at the end: rounds, passes, and where the time went. The same summary goes to `replies/summary.txt`, and `debrief.md` tells Copilot to use it for the Rounds table in place of its own reconstruction.

### Ending

Ctrl-C, `do: stop`, or two hours with no request. On the way out it writes a last reply saying the watch has ended, so Copilot goes back to handing over commands.

### The skill

remote-pair-run gets a section for when a note says `relay watch` is running:

- Write the request in place of a YOUR TURN block with a command. Publish a deliverable and check its manifest first, as now.
- Say in one line what's coming: "Press **y** in the terminal when it asks."
- Wait for the reply, as above. If there's no `.seen` after three minutes, the watch is gone: go back to handing over commands.
- Never ask again for something that was refused or declined. That is the user's answer.

## The unattended mode

Brock asked for a way to make the watch fully automatic, hidden so it can't be turned on easily. This is a named exception to the keypress rule, as the Keychain is to the rule about secrets. When it's built, `AGENTS.md` and [roadmap.md](roadmap.md) say so in those words.

**What it is.** For a limited time, `run`, `apply` and `review` requests are done with no question. Everything else is the same.

**The risk, stated once.** Brock's Copilot Cowork is on his company's enterprise licence. It has no access to the web, its sandbox has no way out to the network, and the company has been assured it is safe for its code and personal details. So what a run reports back stays inside the company's tenant. What remains: Copilot still reads text it didn't write, such as email from outside, Teams messages, documents, and the code and tickets it is given, and any of those can carry a planted instruction. In this mode, a `run.sh` shaped by one would run on a work laptop with nobody reading it first, with the laptop's own network and everything Brock's account can reach. The guards below shrink that. They don't remove it.

**Turning it on.**

- `relay watch --unattended ~/code/thing`. The flag is in no help text, completion or `docs/using.md`. It is described here and nowhere else.
- It needs a terminal, and asks Brock to type a phrase it shows, with the repository's name in it. A single key isn't enough, and nothing piped in can answer.
- It is never a setting or an environment variable, and it isn't remembered. Each session is turned on by hand.
- It lasts 60 minutes. After that the watch goes on in the usual mode, asking again, and says so with a notification.

**What stops it and asks.** Any one of these puts the watch back in the usual mode for that request:

- the deliverable's `runlib.sh` differs from this Mac's copy;
- the secrets check finds something new;
- three runs in a row fail;
- a request is refused.

**What it never does.** It never commits or pushes: `relay apply` doesn't today, and that isn't changed. It never touches a repository the watch wasn't started with.

**Copilot isn't told.** The note, the `.seen` files and the replies read the same in both modes. A planted instruction can't find out that nobody is checking.

**A record.** Each thing done without a question is written to `~/.config/llm-relay/unattended.log`: the time, the request, the deliverable's version and the hash of every file it ran. The terminal shows a banner for as long as the mode is on, and each run still posts a notification.

**No fence round credentials.** Running unattended runs without the environment's tokens, and without read access to `~/.ssh`, `~/.aws` and the like through macOS's `sandbox-exec`, was considered. Dropped on 2026-11-17: Brock's Go builds need those credentials.

## Risks, in the usual mode

- **Code leaves without a keypress.** A `scan` request sends a repository with no question when the secrets check finds nothing new. It can only be a repository Brock named when he started the watch, which is the choice he makes today when he runs `relay scan`.
- **Pressing y without reading.** "What changed since the last yes" is the answer to it. Whether it's enough is a thing to watch for in the field test.
- **Something else on the Mac writes a request.** Any process can write into the OneDrive folder, an agent included. The most it can do is ask for a scan of a named repository, or make the terminal ask a question nobody has to answer **y** to. In the unattended mode it could have a deliverable run, but only one already published in Copilot's output folder with a matching manifest.
- **A flood.** More than 20 requests waiting stops the watch, with a line saying why.

## Waking Copilot with a webhook

Dropped from the plan, since the wait passed its test on 2026-11-17. It would have the relay POST the webhook after each reply, as `relay ask` does. The wake tests of 2026-11-09, in [ask.md](ask.md), found that a webhook run in the same conversation could not write into `Documents/Cowork`, where deliverables and requests live, and that was tried once only. Which conversation a trigger can continue isn't known either.

## Open questions

1. Whether Copilot can wait longer than about 8 minutes in one turn, and whether the wait holds up over many rounds in one session. The first test, in "Copilot waits for the reply itself", passed for two waits.
2. How long a request takes to reach the Mac from Copilot's write. OneDrive to the Mac took about 3 seconds for answers, with two long stalls.
3. Whether the work Mac lets a terminal show a notification. A managed Mac can block it, and the bell still works.
4. Whether Copilot writes requests reliably instead of slipping back into handing over commands.
5. Whether a process left running for hours on OneDrive files meets `Operation not permitted` or `killed` where a single command didn't.

## Order

1. **A short test, with nothing built. Done on 2026-11-17.** Copilot waited in one turn for a file Brock made 2 and then 8 minutes later, and found each by listing the folder. "done" can go. How long Copilot's own file took to reach the Mac wasn't recorded.
2. `relay watch` in the usual mode: requests, `.seen` files and replies, the chain, what changed since the last yes, the tally, the skill's section, and smoke tests with a fake OneDrive folder.
3. A part in the guided field test: a session with the watch, counting Brock's steps against a session without it.
4. The unattended mode, after the usual mode has run for real.

## Decisions

Made on 2026-11-17:

1. Scans on request need no keypress, within the repositories named at the start, with the secrets check as it is.
2. Two hours with no request ends the watch.
3. The name is `relay watch`.
4. One **y** may cover a run and, on a pass, its apply.
5. There will be an unattended mode, hidden and hard to turn on.
6. The unattended mode applies changes as well as running them. It still never commits or pushes.
7. No fence round credentials in the unattended mode, because his Go builds need them.
8. The unattended mode lasts 60 minutes a session, then the watch goes back to asking.
