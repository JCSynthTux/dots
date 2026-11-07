# Local GPU serving (llama.cpp + llama-swap)

OpenCode → **llama-swap** → **llama-server**. OpenCode is a pure HTTP client and
never manages model processes; llama-swap keeps **one model in VRAM at a time**
and hot-swaps (kill + start) when a request names a different model. Target: RX
9060 XT, 16 GB, Navi 44 = gfx1200.

## Fleet: role-specialized, three models

| Role | Model | Quant | Weights | ctx | ttl |
|------|-------|-------|---------|-----|-----|
| orchestrator | `qwen3.8-27b` | UD-Q3_K_XL | ~13.2 GB | 16384 | 1800 s |
| coder, explorer, tester | `glm-4.7-flash` | UD-Q3_K_XL | ~13.8 GB (~12.8 GiB) | 32768 | 3600 s |
| reviewer | `devstral-24b` | Q3_K_M | ~11.5 GB | 24576 | 1800 s |

> **Do not use GLM-4.7-Flash `UD-Q4_K_XL`.** It is 17.5 GB (16.3 GiB) and exceeds
> the card before KV cache, desktop reserve, or compute buffers.

**Swap behaviour:** phase-boundary swaps only — orchestrator → coder → reviewer.
`explorer` and `tester` ride `glm-4.7-flash`, the coder's model, so only the
**coder's** mid-run subagent calls avoid a swap. Orchestrator → explorer/reviewer
dispatch still crosses a model boundary and swaps, which is intended.

## Switching: copy-in-place + git restore

`~/.config/opencode` must be symlinked into this repo, so the copies below write
straight into it. The local variant lives in two inert paths —
`opencode.local-gpu.jsonc` and `agents-local-gpu/` — that OpenCode never reads:
it only scans the fixed `opencode.jsonc` filename and the `agents/` dir. They are
manual snapshots of the cloud setup: when you change your cloud config or agent
definitions, mirror those edits into `opencode.local-gpu.jsonc` and
`agents-local-gpu/` (keeping the local model pins and `providers` block).

**Bring-up (once, from the repo root).** Symlink the config dirs into
`$HOME/.config` by hand. `-sfn` is idempotent over an existing link. Without the
`llama-swap` link the unit's `ConditionPathExists` silently skips; without the
`opencode` link the copy-swap never reaches the live system:

```bash
ln -sfn ~/Projects/dots/.config/llama-swap    ~/.config/llama-swap
ln -sfn ~/Projects/dots/.config/llama.cpp     ~/.config/llama.cpp
ln -sfn ~/Projects/dots/.config/opencode      ~/.config/opencode
```

Check the systemd dir before touching it — link it only if it is **not** already a
symlink into this repo:

```bash
[ -L ~/.config/systemd ] && readlink ~/.config/systemd
# only if the above is not this repo:
ln -sfn ~/Projects/dots/.config/systemd ~/.config/systemd
```

If `~/.config/systemd` is already a symlink into this repo (e.g. from an older
setup), skip the link entirely — the unit is already live. Do **not** link
`llama-swap.service` individually in that case: source and destination resolve to
the same file, and `ln` can replace the tracked unit with a self-referential
symlink.

If a destination already exists as a **real directory**, back it up and remove it
first — `ln -sfn` replaces an existing symlink, not a real directory.

The repo lives at `~/Projects/dots`; adjust if yours differs.

**Switch to local.** Quit the opencode TUI first, and commit or stash any
uncommitted changes under `.config/opencode/` — the `cp` overwrites the live
files, and switching back restores the tracked HEAD versions, not your edits.
Then from the repo root:

```bash
cp .config/opencode/opencode.local-gpu.jsonc .config/opencode/opencode.jsonc
cp .config/opencode/agents-local-gpu/*.md .config/opencode/agents/
systemctl --user enable --now llama-swap
```

Start opencode and check `/agents`: `orchestrator` should show
`local/qwen3.8-27b`, `coder`/`explorer`/`tester` `local/glm-4.7-flash`, and
`reviewer` `local/devstral-24b`; `/models` should list the `local/...` models. If
you did not quit first, run `/reload`.

**Switch back to cloud.** Quit the TUI, then from the repo root:

```bash
systemctl --user disable --now llama-swap
git checkout -- .config/opencode/opencode.jsonc .config/opencode/agents/
```

Run `/reload` after switching back too.

**Safety rules.**

- The swap overwrites tracked files in place, so while in local mode the tree is
  dirty (modified `opencode.jsonc` + 5 agent files, nothing else). Never commit
  in that state: switch back to cloud first, which restores the tracked cloud
  versions via `git checkout --`.
- If anything looks wrong while swapped, quit the TUI and run
  `git checkout -- .config/opencode/opencode.jsonc .config/opencode/agents/`;
  that resets only the swap targets and returns them to the tracked cloud state.
  If a swapped state was accidentally committed, `git revert` that commit
  instead.
- While in local mode, edit `opencode.local-gpu.jsonc` and `agents-local-gpu/`
  (then re-run the two `cp` lines) rather than the live swapped files, whose
  edits are discarded on switch-back.
- Both blocks are idempotent: re-running either leaves the same end state.

The unit is `ConditionPathExists`-guarded on `~/.config/llama-swap/config.yaml`,
so it skips cleanly wherever that config is absent. With copy-in-place the config
keeps existing while you are on cloud, so disabling the unit is about stopping
the proxy and freeing VRAM, not avoiding a dangling symlink.

## 1. Install llama.cpp (AUR / Arch extra)

On this machine llama.cpp comes from the AUR, so the server binary is
**`/usr/bin/llama-server`** (`llama-cli`, `llama-bench` alongside). The
`config.yaml` `cmd`s point there. Two install routes are valid — pick per
preference:

**AUR variants.** `llama.cpp-hip-git` (ROCm/HIP, builds natively for the local
GPU including gfx1200) or `llama.cpp-vulkan-git` (zero-ROCm fallback). These
**CONFLICT**: both own the same `/usr/bin/llama-*` paths, so you cannot have hip
and vulkan installed at once — A/B testing means swapping the package. Naming
varies (`-bin` packages and forks such as `ik-llama.cpp-vulkan` exist), so check
before installing:

```bash
yay -Ss llama.cpp
```

**Official Arch `[extra]` split package** (newer, recommended for A/B):

```bash
pacman -S llama-cpp ggml-hip ggml-vulkan
```

That gives backend-agnostic `/usr/bin` binaries plus co-installable backend
plugins in `/usr/lib/ggml`, so you can A/B backends without reinstalling. The
plugins load automatically; list the devices and pass the index:

```bash
/usr/bin/llama-bench --list-devices
/usr/bin/llama-bench -m ~/.local/share/models/<model>.gguf -dev 0 -ngl 999 -fa 1 -p 512 -n 128 -r 5
```

Run it once with the HIP device and once with the Vulkan device — verify the
exact device flag with `llama-bench --help`, since names vary by version. With
AUR variants, benchmark, swap the package for the other variant, and repeat.

RDNA4/gfx1200 needs **ROCm 7.2+**, where official gfx1200 support landed — use
whatever ROCm your distro currently ships. On the HIP route, verify the GPU
target (this needs `rocm-utils`; a Vulkan-only install may not have it):

```bash
rocminfo | grep gfx   # 9060 XT = gfx1200; gfx1201 is the 9070 family
```

Several controlled tests favour Vulkan on RDNA4 token generation, but your card
and build decide — measure rather than assume.

The `q8_0` KV caches need flash-attention; if llama-server aborts with
"quantized V cache requires flash_attn", your build lacks FA support (common on
some Vulkan builds): use an FA-capable build, or set `--cache-type-v f16` and
lower `--ctx-size`.

## llama.cpp shared config

`~/.config/llama.cpp/config.ini` holds the flags every slot shares, under one
`[*]` section: 99 GPU layers, `flash-attn auto`, `q8_0` K/V caches, `parallel 1`,
batch 1024, 8 threads. The `cmd` blocks then keep only what is per-slot —
`--host`, `--port`, `--model`, `--alias`, `--jinja`, `--ctx-size`; `--jinja`
stays explicit because tool calling depends on it.

Precedence is **config file < environment (`LLAMA_ARG_*`) < CLI flags < model
presets**, so a per-slot flag always wins over the ini.

The ini needs a recent llama.cpp with system-config support (PR #26118; current
AUR `-git` builds qualify). Older builds silently ignore the file, which drops
the `q8_0` KV caches back to f16 — and f16 KV can OOM at 32K. Verify the upstream
startup log instead of assuming: the `llama_kv_cache` line should read
`K (q8_0)` / `V (q8_0)`, and all layers should be offloaded (`offloaded 99/99`,
or `n_gpu_layers = 99`):

```bash
curl -Ns http://127.0.0.1:8080/logs/stream/upstream | grep -E 'q8_0|offloaded'
```

Those lines come from the upstream llama-server, not the llama-swap proxy:
`journalctl --user -u llama-swap -f` only carries them when
`logToStdout: proxy,upstream` is set in `.config/llama-swap/config.yaml` (this
repo leaves the default `proxy`), whereas the `/logs/stream/upstream` endpoint
works regardless — see llama-swap's `/logs` docs. If the line shows f16 or fewer
layers, the ini was ignored and the flags must move back into the `cmd` blocks.

Shell exports live in `.zshrc`: `LLAMA_CACHE=$HOME/.cache/llama.cpp` pins the
cache llama.cpp uses for its own `-hf` downloads, while this guide's
`hf download --local-dir ~/.local/share/models` commands write GGUFs straight
into `~/.local/share/models` — both mechanisms are in play. `HF_TOKEN` is read
from `~/.secrets/hf-token` when present (gated repos). Re-source with
`source ~/.zshrc` or restart the shell.

## 2. Install llama-swap

From the AUR — the source package builds v270 for you, the `-bin` package pulls
the prebuilt GitHub release. Both install to `/usr/bin/llama-swap` and conflict
with each other. Use your AUR helper, e.g.:

```bash
yay -S llama-swap        # or: yay -S llama-swap-bin
```

Both packages also install a **system** unit at
`/usr/lib/systemd/system/llama-swap.service` and a config under
`/etc/llama-swap` (`config.example.yaml` for `llama-swap`, `config.yaml` for
`llama-swap-bin`). This repo's **user** unit passes `--config` explicitly, so do
not adopt or enable the packaged system unit.

llama-swap v270 exits unless told where its config is, so the unit passes
`--config ~/.config/llama-swap/config.yaml` plus `--listen 127.0.0.1:8080` —
loopback only, since otherwise it binds all interfaces with no auth.

## 3. Download models

```bash
mkdir -p ~/.local/share/models
hf download unsloth/Qwen3.8-27B-GGUF --include "*UD-Q3_K_XL*" --local-dir ~/.local/share/models
hf download unsloth/GLM-4.7-Flash-GGUF --include "*UD-Q3_K_XL*" --local-dir ~/.local/share/models
hf download unsloth/Devstral-Small-2-24B-Instruct-2512-GGUF --include "*Q3_K_M*" --local-dir ~/.local/share/models
```

Verify the exact filenames on the HF repos at download time — Unsloth quant
naming varies — then match them to the `--model` paths in `config.yaml`.

## 4. Enable

```bash
systemctl --user daemon-reload && systemctl --user enable --now llama-swap
journalctl --user -u llama-swap -f   # watch loads/swaps
```

## Smoke test (mandatory)

Vendor scores are full-precision claims. Before trusting the fleet, run the same
refactor → fix → patch task against `glm-4.7-flash`, `qwen3.8-27b` and
`devstral-24b` on a real repo and compare the results. Also verify each model
actually emits tool calls in OpenCode: small-model tool calling is binary —
fitting in VRAM is not the same as working.

Finally, confirm the first llama-server start shows the `llama_kv_cache` line with
`K (q8_0)` / `V (q8_0)` and all layers offloaded (`offloaded 99/99`):

```bash
curl -Ns http://127.0.0.1:8080/logs/stream/upstream | grep -E 'q8_0|offloaded'
```

The shared `config.ini` is only safe to rely on once that check passes — a missing
`K (q8_0)`/`V (q8_0)` or a partial offload means the ini was ignored (build too
old), leaving f16 KV and an OOM at 32K. Use the upstream endpoint: journalctl only
shows these lines when `logToStdout: proxy,upstream` is set, which this config
does not.

## VRAM reality (16 GB)

RX 9060 XT: 16 GB, Navi 44 = gfx1200. Reserve **1.0–1.5 GB for the GNOME
desktop** — never budget to 16.0 GB.

`glm-4.7-flash` is the tight slot. At `UD-Q3_K_XL` the 32K default sums to
12.8 GiB weights + ~0.9 GiB q8_0 MLA KV @32K + ~0.8 GiB buffers + 1.5 GiB GNOME
reserve ≈ 16.0 GiB (over the ~15.9 GiB usable card) → hence the first ladder step,
24K ≈ 15.8 GiB, is the realistic GNOME default. `--ctx-size 32768` stays in
`config.yaml` for lean (~1.0 GiB desktop) setups. `qwen3.8-27b` is comfortable by
comparison — its hybrid-attention KV is small at 16K.

| Model | Weights | KV at default ctx | Verdict |
|-------|---------|-------------------|---------|
| `qwen3.8-27b` | ~13.2 GB | q8_0 @16K | ~15 GB total — comfortable for its ctx |
| `glm-4.7-flash` | ~13.8 GB | q8_0 @32K | **tightest slot**; MoE keeps compute cheap |
| `devstral-24b` | ~11.5 GB | q8_0 ~80 KiB/token: ~1.9 GiB @24K, ~2.5 GiB @32K | 32K is the hard ceiling (f16 baseline: 160 KiB/token) |

OOM ladders, in order:

- `glm-4.7-flash`: reduce context 32K → 24K (24576) → 16K. When you take the 24K step,
  ALSO set `"limit": { "context": 24576 }` for `glm-4.7-flash` in
  `.config/opencode/opencode.local-gpu.jsonc` and re-run the copy-in-place `cp` for
  that file — otherwise OpenCode advertises 32768 and can send prompts past the
  server's context. If it still OOMs, move to a smaller Unsloth quant —
  `UD-IQ3_XXS` (~12.9 GB), `UD-Q2_K_XL` (~11.9 GB) or `UD-IQ2_M` (~11.0 GB);
  verify exact filenames on the HF repo at download time. Context reduction cannot
  fix a weights-size problem.
- `qwen3.8-27b`: 16K → 12K → 8K context, or drop to `UD-IQ3_S` (~12.0 GB) or
  `UD-IQ3_XXS` (~10.9 GB).
- `devstral-24b`: 24K → 16K (32K is the hard ceiling).

`--parallel 1` is deliberate: llama-server divides `--ctx-size` across parallel
slots, so a higher value multiplies the KV footprint for no benefit here.

**ReBAR is strongly recommended** for the Vulkan backend — it materially helps
large GGUF allocations, but is not a hard requirement. Check `lspci -vv` for
`Resizable BAR: enabled`.

Only one model is resident, so any request on a *different* model waits for a
swap. That is why `explorer` and `tester` share the coder's model.
