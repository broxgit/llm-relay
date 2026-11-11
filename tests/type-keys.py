#!/usr/bin/env python3
"""Runs a command at a pseudo-terminal and types answers at its prompts, for tests/smoke.sh.

  type-keys.py [--pipe-stdin TEXT] KEYS COMMAND [ARG...]

relay takes its answers from the terminal, so a test can't pipe one in. Each character of KEYS
is typed when the command's output ends in a prompt, one per prompt. A newline is Enter.
--pipe-stdin gives the command a pipe holding TEXT as its standard input, with the terminal
still there. Prints what the terminal showed, and exits as the command did. If a prompt comes
with no keys left, the command is stopped and the exit code is 125. After 300 seconds, 124.
"""
import os
import pty
import select
import signal
import sys
import time

PROMPTS = (b"[n]o: ", b"]: ", b"press a key: ")
LIMIT = 300


def main():
    args = sys.argv[1:]
    piped = None
    if args[:1] == ["--pipe-stdin"]:
        piped = args[1].encode()
        args = args[2:]
    if len(args) < 2:
        sys.exit("usage: type-keys.py [--pipe-stdin TEXT] KEYS COMMAND [ARG...]")
    keys = [k.encode() for k in args[0]]
    command = args[1:]

    pid, fd = pty.fork()
    if pid == 0:
        if piped is not None:
            r, w = os.pipe()
            os.write(w, piped)
            os.close(w)
            os.dup2(r, 0)
            os.close(r)
        try:
            os.execvp(command[0], command)
        except OSError as e:
            os.write(2, ("type-keys.py: %s: %s\n" % (command[0], e)).encode())
            os._exit(127)

    shown = b""
    answered = 0  # How much of the output had been shown when the last key was typed.
    code = None
    started = time.time()
    while True:
        ready, _, _ = select.select([fd], [], [], 0.2)
        data = b""
        if ready:
            try:
                data = os.read(fd, 65536)
            except OSError:  # Linux reports a closed terminal this way.
                data = b""
            if not data:
                break
            shown += data
        if code is None:
            done, status = os.waitpid(pid, os.WNOHANG)
            if done:
                code = exit_code(status)
        if code is not None and not ready:
            break
        if shown[answered:].endswith(PROMPTS):
            if keys:
                os.write(fd, keys.pop(0))
                answered = len(shown)
            else:
                code = stop(pid, 125)
                break
        if time.time() - started > LIMIT:
            code = stop(pid, 124)
            break
    if code is None:
        code = exit_code(os.waitpid(pid, 0)[1])
    sys.stdout.buffer.write(shown.replace(b"\r\n", b"\n"))
    sys.stdout.flush()
    sys.exit(code)


def exit_code(status):
    if os.WIFSIGNALED(status):
        return 128 + os.WTERMSIG(status)
    return os.WEXITSTATUS(status)


def stop(pid, code):
    try:
        os.kill(pid, signal.SIGKILL)
        os.waitpid(pid, 0)
    except OSError:
        pass
    return code


if __name__ == "__main__":
    main()
