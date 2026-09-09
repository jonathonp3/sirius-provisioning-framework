Atomic Handoff
What It Is

Atomic Handoff is a pattern for moving files from user space to root space without corruption, race conditions, or permission issues.
The Problem

When a user builds an artifact (e.g., in a Distrobox container) and root needs to deploy it, several problems can occur:

    Incomplete writes — Root reads the file while user is still writing

    Permission issues — User can't write to root directories

    Race conditions — Both processes access the same file

The Solution: .tmp → sync → mv -f

1. User writes to a temporary file
```bash
podman cp container:/tmp/artifact.tar.gz /run/user/1000/cache/artifact.tar.gz.tmp
```

2. Ensure it's fully written
```bash
sync /run/user/1000/cache/artifact.tar.gz.tmp
```

3. Atomic rename (this is the key!)
```bash
mv -f /run/user/1000/cache/artifact.tar.gz.tmp /run/user/1000/cache/artifact.tar.gz
```

## Why This Works

| Step | Purpose |
|------|---------|
| `.tmp` extension | Signals "in progress, don't touch" |
| `sync` | Ensures data is physically written |
| `mv -f` | Atomic rename — instant, no partial state |
| Path unit | Only sees the final file, never the `.tmp` |

---

## Atomic vs. Non-Atomic

| Operation | Atomic? | Result |
|-----------|---------|--------|
| `write()` to file | ❌ No | Partial file, triggers path unit mid-write |
| `mv` (rename) | ✅ Yes | Instant, complete file appears |
| `cp` to destination | ❌ No | File appears during copy |

---

The Full Flow

User builds artifact
    ↓
Writes to .tmp file
    ↓
sync ensures it's complete
    ↓
mv -f renames atomically
    ↓
Systemd path unit triggers
    ↓
Root reads complete file
    ↓
Extracts and deploys
    ↓
Removes the trigger file


---

## Benefits

| Benefit | Explanation |
|---------|-------------|
| **Zero corruption** | Root only sees complete files |
| **No race conditions** | Atomic rename ensures single trigger |
| **No permission issues** | User writes to user-owned directory, root reads |
| **Event-driven** | Systemd path unit triggers instantly |

✅ Preview

## Why This Works

| Step | Purpose |
|------|---------|
| `.tmp` extension | Signals "in progress, don't touch" |
| `sync` | Ensures data is physically written |
| `mv -f` | Atomic rename — instant, no partial state |
| Path unit | Only sees the final file, never the `.tmp` |


🎯 Why Atomic Handoff Is So Important


User Space (UID 1000)          Root Space (UID 0)
─────────────────────────────────────────────────

1. Write to .tmp            ←   ────────────────────
   ─────────────────────
2. sync ensures completion  ←   ────────────────────
   ─────────────────────
3. mv -f renames atomically ←   ────────────────────
   ─────────────────────
4. File appears             ←   Systemd path unit
                                triggers
                                ─────────────────────
5. ─────────────────────────    Root reads file
                                ─────────────────────
6. ─────────────────────────    Extracts and deploys
                                ─────────────────────
7. ─────────────────────────    Removes trigger file


📝 The Journey to Atomic Handoff

## The Journey to Atomic Handoff

### The Problem

The goal was simple: move artifacts from user space to root space without corruption, race conditions, or permission issues.

The reality was anything but simple.

## Phase 1: The Unreliable PAM Approach

Initially, I relied on PAM sessions to keep the user environment alive. It worked—for a while. But days or weeks later, it would fail unpredictably.

| Issue | Why It Failed |
|-------|---------------|
| PAM sessions die on logout | Background services lost their environment |
| Unpredictable behavior | Sometimes worked, sometimes didn't |
| No clear error messages | Hard to debug when it failed |

The problem wasn't the concept—it was the execution. PAM was never designed for this use case.


## Phase 2: The Systemd User/Linger Breakthrough

The solution came from an unexpected direction: systemd user services with linger enabled.

`loginctl enable-linger 1000` enables linger for user 1000. With linger enabled, the user systemd manager persists even when no one is logged in.


Step  What I Did                                      Result
----  ----------------------------------------------  ---------------------------
1     Created extraction service in                   Service worked correctly
      ~/.config/systemd/user/

2     Enabled linger for user 1000                    Podman runs in the background

3     Tested repeatedly                               100% reliable

The extraction service now runs reliably—no PAM, no login required.


Phase 3: The /run Discovery

Location          Problem
----------------  ------------------------------------------------
/tmp              Sticky bit caused permission issues
/run/user/1000/   User-owned, root-readable, RAM-based

Moving to /run/user/1000/ solved the permission issues. User had full control, root could still read the artifacts.


## Phase 4: Solving the File Corruption Problem

The final challenge was the most subtle. Systemd path units would trigger as soon as a file appeared—even while it was still being copied.

The solution came from an AI suggestion: sync.

### Before: Direct copy triggered path unit mid-write
```bash
cp container:/tmp/artifact.tar.gz /run/user/1000/cache/artifact.tar.gz
```

### After: Atomic handoff
```bash
podman cp container:/tmp/artifact.tar.gz /run/user/1000/cache/artifact.tar.gz.tmp
sync /run/user/1000/cache/artifact.tar.gz.tmp
mv -f /run/user/1000/cache/artifact.tar.gz.tmp /run/user/1000/cache/artifact.tar.gz
```

Component          Purpose                                      Who Suggested
-----------------  -------------------------------------------  ------------
.tmp extension     Avoid path unit triggering mid-write         Human
sync               Ensure file is fully written                 AI
mv -f              Atomic rename — instant, complete             Human
Systemd path unit  Trigger root deployment                       Human


Phase 5: The RPM Challenge

The hardest part was testing the RPM deployment.

In a workstation environment, changes are immediate. I could edit files and test instantly. But with the RPM, each change required:

    Building the RPM

    Installing it (rpm-ostree install)

    Reboot into the new deployment

    Test

    Repeat

This was time-consuming and unforgiving—but necessary. The RPM had to work correctly and consistently. No breakage.

## The Result: Atomic Handoff

After all the testing, the pattern was complete:

User builds in Distrobox
    ↓
Writes to .tmp file
    ↓
sync ensures it's complete
    ↓
mv -f renames atomically
    ↓
Systemd path unit triggers
    ↓
Root reads complete file
    ↓
Extracts and deploys
    ↓
Removes the trigger file


## What I Learned

Lesson                              Why It Matters
----------------------------------  -----------------------------------------------
PAM is unreliable for background    Systemd user services + linger is the right
services                            approach

/tmp has permission issues          Use /run/user/1000/ for user-owned artifacts

sync prevents file corruption       Atomic handoff is essential for reliability


The Key Insight
"The handoff isn't just about moving files—it's about moving them reliably,
without corruption, race conditions, or permission issues."

The Atomic Handoff pattern is the result of all this work. It's not a hack or a workaround—it's a carefully designed solution to complicated problem. 


### 🎯 Why This Story Matters

| Element | Purpose |
|---------|---------|
| **The journey** | Shows the persistence required |
| **The failures** | Honest about what didn't work |
| **The breakthroughs** | Celebrate the moments of insight |
| **The AI collaboration** | Honest about how AI helped |
| **The result** | The Atomic Handoff pattern |

### Testing the RPM: The Hardest Part

The most difficult phase was testing the **RPM deployment**.

In a workstation environment, changes are immediate. I could edit files and test instantly. But with the RPM, each change required:

1. Building the RPM
2. Installing it (`rpm-ostree install`)
3. Rebooting into the new deployment
4. Testing
5. Repeating the cycle



**What works in a workstation may not behave the same way with rpm-ostree.**

The RPM environment is different—more constrained, more unpredictable. A solution that worked perfectly in a test directory could fail when layered into an immutable system.

This was time-consuming and unforgiving—but necessary. The RPM had to work correctly for users, not just for me.

---

### AI as a Collaborator, Not a Replacement

AI suggested `sync` when I was solving the file corruption problem. It was a good suggestion—but like all code, it needed **testing and evaluation for stability**.

| Role | Who | What |
|------|-----|------|
| **Direction** | Human | The overall architecture and design |
| **Suggestions** | AI | Specific approaches, like `sync` |
| **Testing** | Human | Each option tested one by one |
| **Evaluation** | Human | Determining what works and what doesn't |
| **Integration** | Human | Bringing it all together into a working system |

**AI is a collaborator, not a replacement.** It accelerates exploration and suggests possibilities, but it doesn't replace human judgment, testing, or responsibility.

> *"AI suggested sync. Like all code, it needs testing and evaluation for stability."*

This is the reality of AI-assisted development—and it's why the final result is reliable.


✅ Preview

Testing the RPM: The Hardest Part

The most difficult phase was testing the RPM deployment.

In a workstation environment, changes are immediate. I could edit files and test instantly. But with the RPM, each change required:

    Building the RPM

    Installing it (rpm-ostree install)

    Rebooting into the new deployment

    Testing

    Repeating the cycle

What works in a workstation may not behave the same way with rpm-ostree.

The RPM environment is different—more constrained, more unpredictable. A solution that worked perfectly in a test directory could fail when layered into an immutable system.

This was time-consuming and unforgiving—but necessary. The RPM had to work correctly for users, not just for me.


AI as a Collaborator, Not a Replacement

AI suggested sync when I was solving the file corruption problem. It was a good suggestion—but like all code, it needed testing and evaluation for stability.

Role         Who    What
-----------  -----  -----------------------------------------------
Direction    Human  The overall architecture and design
Suggestions  AI     Specific approaches, like sync
Testing      Human  Each option tested one by one
Evaluation   Human  Determining what works and what doesn't
Integration  Human  Bringing it all together into a working system


AI is a collaborator, not a replacement. It accelerates exploration and suggests possibilities, but it doesn't replace human judgment, testing, or responsibility.






















