# Skill sync

**Status: decided on 2026-11-05 and built the same day. It has only run in smoke tests, against a fake OneDrive folder.** This is step 2 of [leverage.md](leverage.md).

The relay copies the Claude skills you name into Cowork's skills folder, adapted for Cowork. The copy is generated on the Mac each time, so your skill in `~/.claude/skills` stays the only thing you edit. A stamp in each copy lets the relay tell, at any time, whether the two are still in step.

## What Brock decided

- Cowork gets an adapted copy, not the skill as it stands. In the first real review, Cowork skipped steps it couldn't do and said so only when asked.
- The adapted copy is generated at copy time. A second file kept by hand would drift.
- There has to be a mechanism that keeps the two in sync, apart from the adaptations.

## What a copy is

Cowork reads skills at `Documents/Cowork/skills/<name>/SKILL.md` in OneDrive, the same shape Claude uses. A copy made by the relay is:

1. The skill's header, unchanged, so Cowork still finds it by name and description.
2. A note from the relay, between two marker lines.
3. The rest of the skill's text, unchanged, byte for byte.
4. The skill's other files, unchanged. `COWORK.md` is the one exception: it isn't copied, because its text is in the note.

The note says:

- The skill was written for Claude on the user's Mac, and its own text follows unchanged.
- Where it says to run `glab` or `git`, or read a clone, use what the relay sent to OneDrive.
- Skip any step that posts, comments, pushes or sends, and say so.
- Where it relies on memory or files on the Mac, say what's missing and ask.
- Which tools the skill names that Cowork doesn't have. The relay finds these by looking for a fixed list of names in the skill's text.
- How to cite the skill, as its name and a short stamp.
- Anything in `COWORK.md`, a file you can put beside a skill for notes that only apply in Cowork.

## The stamp

The note ends with one line the relay reads back:

```
<!-- relay:stamp template 1 | source <hash> | copy <hash> | made <time> -->
```

- `source` is one hash over every file of your skill as it was when the copy was made.
- `copy` is one hash over every file of the copy, leaving out the stamp line.
- `template` is the version of the relay's note.

So a copy describes itself. Nothing about it is kept on the Mac, and a second Mac syncing the same OneDrive reads the same stamps.

## Keeping them in sync

**1. The copy can always be checked against the source.** Take out the lines between the markers, and what's left must be your `SKILL.md`, byte for byte. Every other file must match too. `relay skills` runs that check.

**2. Drift is caught without you remembering.** `relay scan` and `relay mr` look at each named skill before they do anything else. `relay setup` does the same, and is the only one that asks.

| What the relay finds | `scan` and `mr` | `setup` |
|---|---|---|
| No copy in Cowork's folder | Makes it | Makes it |
| Your skill changed since the copy was made | Makes it again, and says so | The same |
| The relay's note changed | Makes it again, and says so | The same |
| The copy was changed in OneDrive | Leaves it, and warns | Shows the difference and asks before replacing it |
| A folder of that name the relay didn't make | Leaves it, and warns | The same |
| A copy the relay made, for a skill you've just taken off the list | Leaves it | Removes it, unless it was changed in OneDrive |

Everything in the first three rows goes from the Mac to OneDrive, so the keypress rule doesn't come into it. A copy changed in OneDrive is text from the cloud. It is never copied to the Mac, and it is only thrown away when you say so.

**3. A review says which copy it used.** Cowork's session keeps its own copy of a skill, which can lag OneDrive by several minutes. So the note asks Cowork to cite the skill with its stamp, and `remote-pair-run` asks for that in a review's Coverage section. `relay review` warns when a review cites a stamp that isn't the current one.

## What you type

```bash
relay setup --skills mr-review:simple-english
```

That names the skills, as a list kept in the settings file, and copies them. `--skills-from` says where they live if it isn't `~/.claude/skills`. `--skills none` clears the list and removes the copies. Only names that were on this Mac's list are removed, so a second Mac sharing the same OneDrive keeps its own.

```bash
relay skills
```

That reports each named skill's state and changes nothing. It exits non-zero if any isn't in step.

## Limits

- **Opt-in only.** Nothing is copied unless you name it. Skills can hold private rules, and OneDrive is the company's cloud, so check what the company allows.
- **One way.** Nothing Cowork writes into a skill comes back to the Mac. If it improves a copy, `relay setup` shows you the difference, and you carry over what you want by hand.
- **Cowork's own limits are enforced.** A copy is refused if its `SKILL.md` is over 1 MB, if it has more than 20 other files, if one is over 5 MB, or if it is over 10 MB in all. Those are Microsoft's documented limits.
- **The name `remote-pair-run` is taken.** That skill is the relay's own and is copied as it is.

## Not known

- Whether Cowork follows the note, and whether the marker lines, which are HTML comments, reach it at all.
- How the relay reads a copy that OneDrive has made cloud-only. If macOS refuses the read, the copy looks changed, and the relay leaves it and warns.
- Whether Cowork cites the stamp when asked. If it doesn't, layer 3 never fires, and layers 1 and 2 still hold.
- Whether a note at the top helps more than `remote-pair-run`'s general paragraph. In [work-mac-session.md](work-mac-session.md), part A hands a skill over to the relay, part D reviews with the adapted copy, and part H checks that the copy keeps up. The baseline is the review of 2026-11-04, which used a hand-made copy with no note.
