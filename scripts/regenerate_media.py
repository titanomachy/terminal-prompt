#!/usr/bin/env python3
"""Record real prompt examples in a PTY and render README GIFs and stills.

Requires POSIX, Nim with package dependencies, asciinema 3, agg 1.9+, and
ImageMagick. Run from any directory; --help lists the available demos.
"""

import argparse
import errno
import fcntl
import json
import os
from pathlib import Path
import pty
import select
import shlex
import signal
import struct
import subprocess
import sys
import tempfile
import termios
import time


ROOT = Path(__file__).resolve().parent.parent
FONT = "JetBrainsMono Nerd Font Mono"
COLS = 64
# Delays precede each key. Final submission follows a pause for the still.
DEMOS = {
    "text_prompt": (4, [(0.8, b"\r"), (1.0, b"n"), (0.16, b"i"),
                       (0.16, b"m"), (0.16, b"-"), (0.16, b"a"),
                       (0.16, b"p"), (0.16, b"p"), (0.9, b"\r")]),
    "password_prompt": (3, [(0.8, b"d"), (0.16, b"e"), (0.16, b"m"),
                           (0.16, b"o"), (0.16, b"-"), (0.16, b"o"),
                           (0.16, b"n"), (0.16, b"l"), (0.16, b"y"),
                           (0.9, b"\r")]),
    "confirm_prompt": (3, [(0.8, b"y"), (0.2, b"e"), (0.2, b"s"),
                          (0.9, b"\r")]),
    "single_select": (7, [(0.8, b"\x1b[B"), (0.7, b"\x1b[A"),
                         (0.9, b"\r")]),
    "multi_select": (7, [(0.8, b"\x1b[B"), (0.5, b" "),
                        (0.7, b"\x1b[B"), (0.5, b" "),
                        (0.7, b" "), (0.9, b"\r")]),
    "prompt_customization": (4, [(0.8, b"A"), (0.2, b"d"), (0.2, b"a"),
                                (0.9, b"\x13")]),
}


def capture(name):
    """Forward actual terminal output; send only the scripted demo keys."""
    rows, keys = DEMOS[name]
    binary = Path(os.environ["TERMINAL_PROMPT_MEDIA_BIN"]) / name
    original = termios.tcgetattr(sys.stdout.fileno())
    output_mode = termios.tcgetattr(sys.stdout.fileno())
    output_mode[1] &= ~termios.OPOST
    termios.tcsetattr(sys.stdout.fileno(), termios.TCSANOW, output_mode)
    pid, master = pty.fork()
    if pid == 0:
        fcntl.ioctl(1, termios.TIOCSWINSZ,
                    struct.pack("HHHH", rows, COLS, 0, 0))
        os.execv(str(binary), [str(binary)])

    next_key = 0
    due = None
    started = time.monotonic()
    exited = False
    try:
        while True:
            now = time.monotonic()
            if now - started > 20:
                raise TimeoutError(f"{name} did not finish within 20 seconds")
            if due is not None and now >= due and next_key < len(keys):
                os.write(master, keys[next_key][1])
                next_key += 1
                due = (now + keys[next_key][0]
                       if next_key < len(keys) else None)
            if select.select([master], [], [], 0.02)[0]:
                try:
                    data = os.read(master, 65536)
                except OSError as error:
                    if error.errno == errno.EIO:
                        break
                    raise
                if not data:
                    break
                sys.stdout.buffer.write(data)
                sys.stdout.buffer.flush()
                if due is None and next_key == 0:
                    # Wait until the prompt has entered raw mode before typing.
                    due = time.monotonic() + keys[0][0]
        _, status = os.waitpid(pid, 0)
        exited = True
        if next_key != len(keys) or os.waitstatus_to_exitcode(status) != 0:
            raise RuntimeError(f"{name} exited before completing the demo")
    finally:
        if not exited:
            os.kill(pid, signal.SIGKILL)
            os.waitpid(pid, 0)
        os.close(master)
        termios.tcsetattr(sys.stdout.fileno(), termios.TCSANOW, original)


def recording_positions(cast, rows):
    """Inspect metadata and find full initial, pre-submit, and final frames."""
    lines = cast.read_text().splitlines()
    header = json.loads(lines[0])
    assert header["version"] == 3
    assert header["term"]["cols"] == COLS
    assert header["term"]["rows"] == rows
    assert header["env"] == {"TERM": "xterm-256color", "COLORTERM": "truecolor"}
    events = [json.loads(line) for line in lines[1:]]
    assert all(event[1] != "i" for event in events), "Input must not be captured"
    output = [(index, event[2]) for index, event in enumerate(events)
              if event[1] == "o"]
    # The first output can contain only terminal setup; wait for the question.
    first = next(index for index, data in output if "? " in data)
    # Cleanup restores the cursor after the final answer; skip such output.
    final = next(index for index, data in reversed(output)
                 if any(result in data for result in
                        ("Creating ", "Token received.", "Skipped.", "Port: ",
                         "Enabled: ", "Hello, ")))
    snapshot = max(index for index, _ in output if index < final)
    if cast.stem == "password_prompt":
        assert "demo-only" not in "".join(data for _, data in output)
    return first, snapshot, final


def run(command, **kwargs):
    subprocess.run(command, cwd=ROOT, check=True, **kwargs)


def regenerate(names):
    images = ROOT / "docs" / "images"
    recordings = ROOT / "docs" / "recordings"
    images.mkdir(parents=True, exist_ok=True)
    recordings.mkdir(parents=True, exist_ok=True)
    matched = subprocess.check_output(
        ["fc-match", "-f", "%{family}", FONT], text=True)
    if FONT not in matched.split(","):
        raise RuntimeError(f"Install the exact font family: {FONT}")

    with tempfile.TemporaryDirectory(prefix="terminal-prompt-media-") as temporary:
        environment = os.environ.copy()
        environment.update(TERM="xterm-256color", COLORTERM="truecolor",
                           TERMINAL_PROMPT_MEDIA_BIN=temporary)
        environment.pop("NO_COLOR", None)
        for name in names:
            print(f"Generating {name}", flush=True)
            run(["nim", "c", "-d:release", "--path:src", "--hints:off",
                 f"--nimcache:{temporary}/nimcache",
                 f"--out:{temporary}/{name}", f"examples/{name}.nim"])
            rows = DEMOS[name][0]
            cast = recordings / f"{name}.cast"
            command = shlex.join(["python3", "scripts/regenerate_media.py",
                                  "--capture", name])
            run(["asciinema", "record", "--headless", "--quiet", "--return",
                 "--window-size", f"{COLS}x{rows}", "--capture-env",
                 "TERM,COLORTERM", "--title", f"TerminalPrompt: {name}",
                 "--command", command, "--overwrite", str(cast)],
                env=environment)
            first, snapshot, final = recording_positions(cast, rows)
            options = ["agg", "--quiet", "--text-font-family", FONT,
                       "--font-size", "18", "--line-height", "1.4",
                       "--renderer", "swash", "--theme", "github-dark",
                       "--idle-time-limit", "1", "--last-frame-duration", "2"]
            run(options + ["--select", f"event:{first}..event:{final}",
                           str(cast), str(images / f"{name}.gif")])
            still = Path(temporary) / f"{name}-still.gif"
            run(options + ["--select", f"event:{snapshot}", str(cast), str(still)])
            run(["magick", f"{still}[0]", str(images / f"{name}.png")])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--only", nargs="+", choices=DEMOS,
                        help="regenerate only these demos (default: all six)")
    parser.add_argument("--capture", choices=DEMOS, help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.capture:
        capture(args.capture)
    else:
        regenerate(args.only or list(DEMOS))


if __name__ == "__main__":
    main()
