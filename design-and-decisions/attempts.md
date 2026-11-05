# Attempts: several tries in one run

**Status: Brock said to build it on 2026-11-05. It has only run in smoke tests.** This is step 5 of [leverage.md](leverage.md).

One deliverable can now carry several ways of fixing the same thing. The run tries them in order, each in its own fresh copy of the code, and stops at the first that passes. You still read the deliverable and press `y` once, so one keypress buys several iterations.

## Why

Every round costs a keypress and a few minutes of OneDrive. When Cowork isn't sure which of two or three fixes will work, it has had to pick one, wait for the report, and try the next in another round. Often it could have written all three at the start.

## How a run with attempts works

```bash
try_bump() {
  apply_attempt_patches
  check "go build" bash -c "cd '$WORKTREE' && go build ./..."
  check "go test" bash -c "cd '$WORKTREE' && go test ./..."
}
try_pin() {
  apply_attempt_patches
  check "go build" bash -c "cd '$WORKTREE' && go build ./..."
  check "go test" bash -c "cd '$WORKTREE' && go test ./..."
}

step "Fix the build"
attempt bump-driver "$repo" "$commit" try_bump ||
  attempt pin-yaml "$repo" "$commit" try_pin
```

- **Each attempt gets a fresh worktree** of the commit, with git hooks off, the same way `safe_worktree` makes one. It is removed when the attempt ends. The user's checkout is never touched, and the run still proves that at the end.
- **An attempt's results are its own.** A failed check inside an attempt doesn't fail the run. The attempt as a whole passes only if it ran at least one check and none failed.
- **`attempt` returns whether it passed,** so `||` moves on to the next only after a failure.
- **The run passes if one attempt passed.** If none did, the run fails, and the summary gives each attempt's first failure.
- **An `abort` inside an attempt ends that attempt,** not the run. The attempt's function runs in a subshell.

## Where the patches go

```
<deliverable>/
  run.sh
  runlib.sh
  common.patch              Applied in every attempt, and by relay apply.
  attempts/
    bump-driver/1-go-mod.patch
    pin-yaml/1-go-mod.patch
    pin-yaml/2-config.patch
```

`apply_attempt_patches` applies the top-level patches, then that attempt's, in name order, each as a check. `relay apply` applies exactly the same set in the same order for the attempt that passed. So what lands in the working tree is what the run proved.

## How `relay apply` knows which passed

The report's summary has one line for it:

```
attempt passed: pin-yaml
```

`relay apply` reads that line from the report of the same version. It only trusts a report in OneDrive that is identical to the copy this Mac kept in `~/pair-run-reports`, because the report folder is in the cloud and the choice of patches hangs on it. Then it shows the attempt and its patches, and asks, as before.

If a deliverable has attempts and no report shows one that passed, `relay apply` stops and says to run it first. It never applies an attempt that wasn't proven.

## Limits

- **Attempts start from a commit.** Uncommitted work in the user's checkout isn't in the worktree. If it matters, Cowork asks the user to commit it to a branch first.
- **No `on_exit` inside an attempt.** The function runs in a subshell, and its worktree is thrown away anyway.
- **Names are plain:** letters, digits, dots, dashes and underscores, because a name is also a folder.
- **A deliverable needs the new `runlib.sh`.** Cowork copies it from the skill's folder, so `relay setup` has to run after updating, and Cowork has to check its copy says `RUNLIB_VERSION=5` or more.

## Not known

- Whether Cowork writes good alternatives when asked for several, or pads a deliverable with weak ones.
- How long three sets of builds take in one run on real code. The checks inside each attempt are the same ones a single round would run.
