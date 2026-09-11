Atomic Handoff
What It Is

Atomic Handoff is a pattern for moving files from user space to root space without corruption, race conditions, or permission issues.
The Problem

When a user builds an artifact (e.g., in a Distrobox container) and root needs to deploy it, several problems can occur:

    Incomplete writes — Root reads the file while user is still writing

    Permission issues — User can't write to root directories

    Race conditions — Two processes access the same file at the same time

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

Moving to /run/user/1000/ solved the permission issues. The user has full control while root can read the artifacts.


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

Component          Purpose                                      
-----------------  -------------------------------------------  
.tmp extension     Avoid path unit triggering mid write        
sync               Ensure file is fully written                 
mv -f              Atomic rename — instant, complete            
Systemd path unit  Trigger root deployment                   


## Phase 5: The RPM Challenge

The hardest part was testing the RPM deployment.

In a workstation environment, changes are immediate. I could edit files and test instantly. But with the RPM, each change required:

    Building the RPM

    Installing it (rpm-ostree install)

    Reboot into the new deployment

    Test

    Repeat

This was time consuming process. The RPM had to work correctly and consistently with out error.

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


## What I Learn't from this project

Lesson                              Why It Mattered
----------------------------------  -----------------------------------------------
PAM is unreliable for background    Systemd user services + linger is the right
services                            approach

/tmp has limitations                Best to use /run/user/1000/ for user-owned artifacts

sync prevents file corruption       Atomic handoff is a better approach


Insight

"The handoff allows file to be moved without corruption, race conditions and permission issues."




