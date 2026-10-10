# README recordings

Each `.cast` records a real program from `examples/`, driven with timed keys
through a POSIX pseudo-terminal. Asciinema captures output only; the password
demo uses a dummy value and its recording contains only mask characters.
The GIFs and PNG snapshots live in [`../images/`](../images/).

## Regenerate

Install the package dependencies and prepare paths for direct Nim compilation:

```sh
nimble install --depsOnly
nimble setup
```

Install Asciinema 3, Agg 1.9 or newer, ImageMagick, and the exact font family
`JetBrainsMono Nerd Font Mono`. The recorder uses Python 3's standard library
and POSIX PTYs; it does not require a live terminal or Python packages.

From the repository root:

```sh
python3 scripts/regenerate_media.py
python3 scripts/regenerate_media.py --only single_select
```

The script builds release executables and compiler caches in `/tmp`, records
finite sessions, checks the cast metadata, and replaces the matching assets.
The internal `--capture` commands in the cast headers run through this script,
which supplies the temporary binary directory.

## Rendering

All terminals are 64 columns wide. Agg uses `JetBrainsMono Nerd Font Mono` at
18 px, line height 1.4, the Swash renderer, and the `github-dark` theme. Idle
time is limited to one second, with a two-second final frame. PNGs show the
state immediately before submission, rendered at the same resolution.

| Example / asset stem | Terminal geometry | GIF / PNG dimensions |
| --- | --- | --- |
| `text_prompt` | 64 × 4 | 713 × 126 px |
| `password_prompt` | 64 × 3 | 713 × 101 px |
| `confirm_prompt` | 64 × 3 | 713 × 101 px |
| `single_select` | 64 × 7 | 713 × 202 px |
| `multi_select` | 64 × 7 | 713 × 202 px |
| `prompt_customization` | 64 × 4 | 713 × 126 px |

GIF intervals begin with the first question and end with the submitted result,
excluding any terminal setup or teardown output. These prompts use transient
frames rather than the alternate screen. Render selectors are derived from
each new cast's events; no timestamps are copied between recordings.

After changing a demo, check the GIF's frame count and coalesce it before
inspecting the first and last frames:

```sh
identify docs/images/single_select.gif
magick docs/images/single_select.gif -coalesce /tmp/prompt-frame-%02d.png
```

Check for clipping, stale redraws, blank transition frames, and unintended
cursor artifacts. Cast headers include only the command, title, geometry,
timestamp, `TERM`, and `COLORTERM`; never enable input capture or add secrets
to recording metadata.
