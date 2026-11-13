# Local GPU serving (llama.cpp + llama-swap)

OpenCode → **llama-swap** → **llama-server**. OpenCode is a pure HTTP client and
never manages model processes; llama-swap keeps **one model in VRAM at a time**
and hot-swaps (kill + start) when a request names a different model. Target: RX
9060 XT, 16 GB, Navi 44 = gfx1200.

## Fleet: one resident model, two siblings

| Role | Model | Quant | Weights | ctx | ttl |
|------|-------|-------|---------|-----|-----|
| orchestrator | `qwen-27b-think` (Qwen3.8-27B) | UD-IQ3_XXS | ~10.9 GB (~10.2 GiB) | 65536 | 1800 s |
| coder, explorer, reviewer, tester | `qwen-27b` (same GGUF) | UD-IQ3_XXS | ~10.9 GB (~10.2 GiB) | 65536 | 1800 s |
| researcher (dedicated primary) | `qwen-heretic-8b` | Q4_K_M | ~4.7 GB | 32768 | 1800 s |

`qwen-27b` and `qwen-27b-think` are the **same weights** with different server
flags, exposed as two model IDs. llama-swap keeps one resident, so every
orchestrator ↔ subagent hand-off reloads the same GGUF (~10-30 s warm from page
cache). The trade is deliberate: the orchestrator gets long thinking for
planning, while coder/explorer/reviewer/tester stay on the fast no-thinking
slot. The researcher is user-invoked (primary mode), so selecting it swaps the
resident model once — it does not co-run with the coding fleet.

`qwen-27b` runs with thinking **off** (`--reasoning off`): the chat template
defaults to thinking at `xhigh`, which burns thousands of tokens before the
first tool call on a 27B IQ3 at ~26 tok/s. `qwen-27b-think` runs with
`--reasoning on --reasoning-format deepseek --reasoning-effort high` (this
template maps `high` → `xhigh`); thoughts arrive in `reasoning_content`, which
OpenCode shows when `capabilities.reasoning.supported` is true. Thinking shares
the 8192 output budget, so a truncated answer means lowering the effort or
raising `limit.output`. If xhigh is too slow, switch the slot to
`--reasoning-effort medium`.

MTP speculative decoding is enabled (`--spec-type draft-mtp`; the GGUF carries
one `nextn` layer). Measured acceptance on this card is 87–100%, lifting
generation to ~26 tok/s with no second model. Prompt processing is ~426 tok/s
at ubatch 1024.

## Switching: copy-in-place + git restore

`~/.config/opencode` must be symlinked into this repo, so the copies below write
straight into it. The local variant lives in two inert paths —
`opencode.local-gpu.jsonc` and `agents-local-gpu/` — that OpenCode never reads:
it only scans the fixed `opencode.jsonc` filename and the `agents/` dir. They are
manual snapshots of the cloud setup: when you change your cloud config or agent
definitions, mirror those edits into `opencode.local-gpu.jsonc` and
`agents-local-gpu/` (keeping the local model pins and `providers` block).
Exception: the two `researcher.md` files deliberately diverge — the cloud
`researcher` is an orchestrator subagent, the local one a user-invoked primary
(the uncensored model is only crossed by explicit user choice). Don't mirror
mode or workflow wiring between them; still mirror behavioral bullets like the
sourcing rule.

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

**If the live paths are real directories** (this machine:
`readlink -f ~/.config/llama-swap` returns the path itself), the repo is *not*
live. Keep them as copies and sync the two runtime files after every edit, then
restart the proxy:

```bash
cp .config/llama-swap/config.yaml ~/.config/llama-swap/config.yaml
cp .config/llama.cpp/config.ini   ~/.config/llama.cpp/config.ini
systemctl --user restart llama-swap
```

Editing the repo alone changes nothing in that layout — the service keeps
reading the old copies. The same applies to `opencode.local-gpu.jsonc` and
`agents-local-gpu/`; the switch-to-local `cp` below already reads the repo
versions, so refresh the live snapshots only if you use them outside the switch.

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
`local/qwen-27b-think`; `coder`, `explorer`, `reviewer`, and `tester`
`local/qwen-27b`; `researcher` `local/qwen-heretic-8b`; `/models` should list
all three `local/...` models. If you did not quit first, run `/reload`.

**Switch back to cloud.** Quit the TUI, then from the repo root:

```bash
systemctl --user disable --now llama-swap
git checkout -- .config/opencode/opencode.jsonc .config/opencode/agents/
```

`git checkout --` restores the tracked cloud files, including the cloud
`researcher.md` that the switch overwrote with the local variant. No `rm -f` is
needed: `researcher.md` is now tracked, so nothing untracked is left behind.

Run `/reload` after switching back too.

**Safety rules.**

- The swap overwrites tracked files in place, so while in local mode the tree is
  dirty: modified `opencode.jsonc` plus all 6 tracked agent files (including
  `researcher.md`, which the local copy overwrites). Never commit in that state:
  switch back to cloud first, which restores the tracked cloud versions via
  `git checkout --`.
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
`[*]` section: 99 GPU layers, `flash-attn on`, `q8_0` K/V caches, `parallel 1`,
batch 2048, ubatch 1024, 8 threads. The `cmd` blocks then keep only what is
per-slot — `--host`, `--port`, `--model`, `--alias`, `--jinja`, `--ctx-size`,
plus the model-specific `--reasoning off`, MTP, and sampling flags. `--jinja`
stays explicit because tool calling depends on it.

The env spellings are `LLAMA_ARG_BATCH` and `LLAMA_ARG_N_PARALLEL`; the older
`LLAMA_ARG_BATCH_SIZE` / `LLAMA_ARG_PARALLEL` keys are silently ignored
(`not supported by this program` in the log), which drops parallel back to auto
and ubatch back to 512. A correctly read ini logs `n_slots = 1` and
`n_ctx_slot = 65536`. ubatch 1024 measured ~426 tok/s prompt processing here
versus ~225 tok/s at 512; drop it back to 512 if a load OOMs.

Precedence is **config file < environment (`LLAMA_ARG_*`) < CLI flags < model
presets**, so a per-slot flag always wins over the ini.

The ini needs a recent llama.cpp with system-config support (PR #26118; current
AUR `-git` builds qualify). Older builds silently ignore the file, which drops
the `q8_0` KV caches back to f16 — and f16 KV can OOM at 64K. Verify the upstream
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
hf download unsloth/Qwen3.8-27B-GGUF --include "*UD-IQ3_XXS*" --local-dir ~/.local/share/models
hf download mradermacher/Qwen3-8B-ZeroZero-Heretic-GGUF --include "*Q4_K_M*" --local-dir ~/.local/share/models
```

Verify the exact filenames on the HF repos at download time — Unsloth quant
naming varies — then match them to the `--model` paths in `config.yaml`.

## 4. Enable

```bash
systemctl --user daemon-reload && systemctl --user enable --now llama-swap
journalctl --user -u llama-swap -f   # watch loads/swaps
```

## Uncensored researcher model — tool-calling caveat

`qwen-heretic-8b` ships a Hermes-style `<tool_call>` template, which is present in the
GGUF's chat template, but its reliability under llama.cpp/OpenCode is unproven.
llama.cpp does not reliably log which chat template it loaded, so a log line is
not proof: the definitive check is a real `<tool_call>` round-trip from the
researcher, which the smoke test below covers.

If `<tool_call>` parsing fails or the model simply will not call tools, switch the
slot's `--model` to the abliterated Dolphin fallback —
`mradermacher/Dolphin3.0-Llama3.1-8B-abliterated-GGUF`, Q4_K_M (~4.9 GB, proven
function-calling lineage, Llama 3.1 license) — and re-run the smoke test. Note
that reasoning models can be tool-reluctant; a firm system prompt helps.

## Smoke test (mandatory)

Vendor scores are full-precision claims. Before trusting the fleet, run the same
refactor → fix → patch task against `qwen-27b` on a real repo. Also verify the
model actually emits tool calls in OpenCode: small-model tool calling is binary —
fitting in VRAM is not the same as working. The `qwen-27b` (fast) slot should
answer directly (no `<think>` prefix) and return `reasoning_content: null`; the
`qwen-27b-think` slot should return a non-empty `reasoning_content` before the
answer. Tool-call responses should carry `finish_reason: tool_calls` on both.

Quick check of the thinking slot:

```bash
curl -s http://127.0.0.1:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"qwen-27b-think","messages":[{"role":"user","content":"What is 17*23?"}],"max_tokens":512}' \
  | jq '{reasoning_len: (.choices[0].message.reasoning_content // "" | length), content: .choices[0].message.content}'
```

A non-zero `reasoning_len` confirms `--reasoning on` took effect.

The researcher needs this check most of all: switch to `qwen-heretic-8b`, ask it a
question that requires a searxng search, and confirm it emits a tool call instead
of answering from memory. If it does not, take the Dolphin fallback above.

Finally, confirm the first llama-server start shows the `llama_kv_cache` line with
`K (q8_0)` / `V (q8_0)` and all layers offloaded (`offloaded 99/99`):

```bash
curl -Ns http://127.0.0.1:8080/logs/stream/upstream | grep -E 'q8_0|offloaded|MTP|n_ctx_slot'
```

A correct `qwen-27b` or `qwen-27b-think` start also logs `n_slots = 1`,
`n_ctx_slot = 65536`, and `creating MTP draft context`. Check the effective
context and slot count:

```bash
curl -s http://127.0.0.1:8080/props | jq '{ctx: .default_generation_settings.n_ctx, slots: .total_slots}'
```

The shared `config.ini` is only safe to rely on once that check passes — a missing
`K (q8_0)`/`V (q8_0)` or a partial offload means the ini was ignored (build too
old), leaving f16 KV and an OOM at 64K. Use the upstream endpoint: journalctl only
shows these lines when `logToStdout: proxy,upstream` is set, which this config
does not.

## VRAM reality (16 GB)

RX 9060 XT: 16 GB (15.92 GiB usable), Navi 44 = gfx1200. With llama-swap
stopped and GNOME idle, the desktop reserves ~1.2 GiB — never budget to 16.0 GB.

`qwen-27b` is a hybrid-attention model: only every fourth of its 65 layers is
full attention. At q8_0 that is ~34 KiB of KV per token, so context is cheap:

| Model / config | Weights | KV | Measured total | Verdict |
|----------------|---------|----|----------------|---------|
| `qwen-27b` @64K, ubatch 1024 | 10.18 GiB | 2.1 GiB | 14.08 GiB | **default**; ~1.85 GiB free |
| `qwen-27b` @80K, ubatch 1024 | 10.18 GiB | 2.6 GiB | 15.09 GiB | ~0.83 GiB free — too tight |
| `qwen-27b` @96K, ubatch 512 | 10.18 GiB | 3.2 GiB | 14.81 GiB | ~1.1 GiB free, but prefill halves |
| `qwen-heretic-8b` @32K | 4.7 GB | 2.4 GiB | ~8.4 GiB | comfortable |

64K with ubatch 1024 is the best balance: ~426 tok/s prefill and ~1.8 GiB of
headroom for the desktop. The 80K/96K rows fit only if you close GPU-heavy apps;
they are not worth the prefill penalty or the OOM risk. `qwen-27b-think` has the
same weights and context, so the same ~14.08 GiB applies; only the flags differ.

OOM ladder, in order:

- `qwen-27b` / `qwen-27b-think`: ubatch 1024 → 512 first (frees ~0.7 GiB but
  halves prefill), then context 64K (65536) → 48K (49152) → 32K (32768).
- Whenever you change `--ctx-size`, set the same value in
  `"limit": { "context": ... }` for **both** `qwen-27b` and `qwen-27b-think` in
  `.config/opencode/opencode.local-gpu.jsonc` and re-run the copy-in-place `cp`
  for that file — otherwise OpenCode advertises more context than the server
  has, and requests fail instead of compacting.
- `qwen-heretic-8b` needs no ladder: ~4.7 GB weights + ~2.4 GiB q8_0 KV @32K
  + overhead lands around 8.4 GiB.

`--parallel 1` is deliberate: this build's `auto` default created four slots,
and each slot carries its own context bookkeeping. One slot keeps a single 64K
allocation and avoids slot/checkpoint overhead for a single-user setup.

MTP (`--spec-type draft-mtp`) uses the model's built-in `nextn` layer, so it
adds no second model and no meaningful VRAM. Generation measured ~26 tok/s with
87–100% draft acceptance.

**ReBAR is strongly recommended** for the Vulkan backend — it materially helps
large GGUF allocations, but is not a hard requirement. Check `lspci -vv` for
`Resizable BAR: enabled`.

Only one model is resident, so any request on a *different* model waits for a
swap. The orchestrator deliberately crosses that boundary: its think slot is
unloaded for each coder/reviewer/tester call and reloaded when the result comes
back. Only the researcher crosses it by user choice.
