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
mkdir -p ~/.config/systemd/user
ln -sfn ~/Projects/dots/.config/llama-swap    ~/.config/llama-swap
ln -sfn ~/Projects/dots/.config/opencode      ~/.config/opencode
ln -sfn ~/Projects/dots/.config/systemd/user/llama-swap.service ~/.config/systemd/user/llama-swap.service
```

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

## 1. Build llama.cpp (RDNA4)

Build both backends and A/B them. **Default to Vulkan for GGUF on Linux**, though
some RDNA4 setups favour ROCm; ROCm ≥ 7.0.2 is needed for gfx1200:

```bash
cmake -B build-vulkan -DGGML_VULKAN=ON -DCMAKE_BUILD_TYPE=Release
cmake --build build-vulkan --config Release -j"$(nproc)"

cmake -B build-rocm -DGGML_HIP=ON -DGPU_TARGETS=gfx1200 -DCMAKE_BUILD_TYPE=Release
cmake --build build-rocm --config Release -j"$(nproc)"
```

Install the binaries from whichever build you chose — both trees produce
`llama-server` and `llama-bench`:

```bash
# Vulkan
install -Dm755 build-vulkan/bin/llama-server ~/.local/bin/llama-server
install -Dm755 build-vulkan/bin/llama-bench  ~/.local/bin/llama-bench
# or ROCm
install -Dm755 build-rocm/bin/llama-server   ~/.local/bin/llama-server
install -Dm755 build-rocm/bin/llama-bench    ~/.local/bin/llama-bench
```

Benchmark the same GGUF with each build's own `llama-bench` and compare:

```bash
build-vulkan/bin/llama-bench -m ~/.local/share/models/<model>.gguf -ngl 999 -fa 1 -p 512 -n 128 -r 5
build-rocm/bin/llama-bench   -m ~/.local/share/models/<model>.gguf -ngl 999 -fa 1 -p 512 -n 128 -r 5
```

Confirm the target with `rocminfo | grep gfx`: the 9060 XT is `gfx1200`, while
`gfx1201` is the 9070 family — do not mix them up when setting `-DGPU_TARGETS`.

The `q8_0` KV caches need flash-attention; if llama-server aborts with
"quantized V cache requires flash_attn", your build lacks FA support (common on
some Vulkan builds): use an FA-capable build, or set `--cache-type-v f16` and
lower `--ctx-size`.

## 2. Install llama-swap

```bash
go install github.com/mostlygeek/llama-swap@latest
install -Dm755 "$(go env GOPATH)/bin/llama-swap" ~/.local/bin/llama-swap
```

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

## VRAM reality (16 GB)

RX 9060 XT: 16 GB, Navi 44 = gfx1200. Reserve **1.0–1.5 GB for the GNOME
desktop** — never budget to 16.0 GB.

`glm-4.7-flash` is the tight slot. At `UD-Q3_K_XL` (~12.8 GiB weights) plus a
q8_0 MLA cache (~0.9 GiB @32K) and ~0.8 GiB of compute buffers, the 32K default
totals ~16.0 GiB — viable only with a lean (~1.0 GiB) desktop footprint. Under a
typical GNOME session (1.5 GiB reserve) expect to take the first ladder step to
24K (~15.8 GiB), which is the realistic default; `--ctx-size 32768` stays in
`config.yaml` for lean setups. `qwen3.8-27b` is comfortable by comparison — its
hybrid-attention KV is small at 16K.

| Model | Weights | KV at default ctx | Verdict |
|-------|---------|-------------------|---------|
| `qwen3.8-27b` | ~13.2 GB | q8_0 @16K | ~15 GB total — comfortable for its ctx |
| `glm-4.7-flash` | ~13.8 GB | q8_0 @32K | **tightest slot**; MoE keeps compute cheap |
| `devstral-24b` | ~11.5 GB | q8_0 ~80 KiB/token: ~1.9 GiB @24K, ~2.5 GiB @32K | 32K is the hard ceiling (f16 baseline: 160 KiB/token) |

OOM ladders, in order:

- `glm-4.7-flash`: reduce context 32K → 24K → 16K; if it still OOMs, move to a
  smaller Unsloth quant — `UD-IQ3_XXS` (~12.9 GB), `UD-Q2_K_XL` (~11.9 GB) or
  `UD-IQ2_M` (~11.0 GB); verify exact filenames on the HF repo at download time.
  Context reduction cannot fix a weights-size problem.
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
