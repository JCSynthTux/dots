# Local GPU serving (llama.cpp + llama-swap)

OpenCode → **llama-swap** → **llama-server**. OpenCode is a pure HTTP client;
llama-swap keeps **one model in VRAM at a time** and hot-swaps (kill + start)
when a request names a different model. Target: RX 9060 XT, 16 GB, RDNA4 (gfx1200/gfx1201).

Agents: `orchestrator`, `coder`, `reviewer` → `qwen2.5-coder-14b`; `explorer`, `tester` → `qwen3-8b`.

## Switching: copy-in-place + git restore

`~/.config/opencode` is symlinked into this repo (via `install.sh --link`), so
the copies below write straight into the repo. The local variant lives in two
inert paths — `opencode.local-gpu.jsonc` and `agents-local-gpu/` — that OpenCode
never reads: it only scans the fixed `opencode.jsonc` filename and the `agents/`
dir.

**Bring-up (once, from the repo root).** This symlinks the new
`~/.config/llama-swap/` dir into `$HOME/.config`; without it the unit's
`ConditionPathExists` silently skips:

```bash
./install.sh --link
```

**Switch to local.** Quit the opencode TUI first, then from the repo root:

```bash
cp .config/opencode/opencode.local-gpu.jsonc .config/opencode/opencode.jsonc
cp .config/opencode/agents-local-gpu/*.md .config/opencode/agents/
systemctl --user enable --now llama-swap
```

Start opencode and check `/agents`: orchestrator/coder/reviewer should show
`local/qwen2.5-coder-14b`, explorer/tester `local/qwen3-8b`; `/models` should
list the `local/...` models. If you did not quit first, run `/reload`.

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
  `git checkout -- .config/opencode/`; that always returns to the tracked cloud
  state.
- Both blocks are idempotent: re-running either leaves the same end state.

The unit is `ConditionPathExists`-guarded on `~/.config/llama-swap/config.yaml`,
so it skips cleanly wherever that config is absent. With copy-in-place the config
keeps existing while you are on cloud, so disabling the unit is about stopping
the proxy and freeing VRAM, not avoiding a dangling symlink.

## 1. Install llama.cpp (RDNA4)

Needs **ROCm ≥ 7.0.2** for gfx1200/gfx1201; CachyOS ships a recent ROCm.

```bash
cmake -B build -DGGML_HIP=ON -DCMAKE_BUILD_TYPE=Release -DAMDGPU_TARGETS=gfx1200
cmake --build build --config Release -j"$(nproc)"
install -Dm755 build/bin/llama-server ~/.local/bin/llama-server
```

Vulkan fallback — benchmark both on this card, some AMD setups favor Vulkan:

```bash
cmake -B build-vk -DGGML_VULKAN=ON -DCMAKE_BUILD_TYPE=Release
cmake --build build-vk --config Release -j"$(nproc)"
install -Dm755 build-vk/bin/llama-server ~/.local/bin/llama-server
```

The `q8_0` KV caches need flash-attention; if llama-server aborts with
"quantized V cache requires flash_attn", your build lacks FA support (common on
Vulkan): use an FA-capable build, or set `--cache-type-v f16` and lower `--ctx-size`.

## 2. Install llama-swap

```bash
go install github.com/mostlygeek/llama-swap@latest
install -Dm755 "$(go env GOPATH)/bin/llama-swap" ~/.local/bin/llama-swap
```

llama-swap v270 exits unless told where its config is, so the unit passes
`--config ~/.config/llama-swap/config.yaml` plus `--listen 127.0.0.1:8080` —
loopback only, since otherwise it binds all interfaces with no auth.

## 3. Download models

~8.4 GiB + ~5 GiB of weights; adjust `--model` paths if stored elsewhere.

```bash
mkdir -p ~/.local/share/models
hf download bartowski/Qwen2.5-Coder-14B-Instruct-GGUF \
  Qwen2.5-Coder-14B-Instruct-Q4_K_M.gguf --local-dir ~/.local/share/models
hf download Qwen/Qwen3-8B-GGUF \
  Qwen3-8B-Q4_K_M.gguf --local-dir ~/.local/share/models
```

## 4. Enable

```bash
systemctl --user daemon-reload && systemctl --user enable --now llama-swap
journalctl --user -u llama-swap -f   # watch loads/swaps
```

## VRAM reality (16 GB)

The 14B at 32k ≈ 8.4 GiB weights + ~3 GiB q8_0 KV + compute buffers ≈ 12 GiB —
comfortable. The 8B ≈ 5 GiB weights + ~1.5 GiB KV ≈ 7 GiB. Only one model is
resident, so subagents on *different* models serialize behind a swap costing a
few seconds — hence `explorer`/`tester` share the 8B, the rest share the 14B.

The 8B's long `ttl` only survives idle gaps between explorer/tester calls; any
14B request still evicts it (single slot) and pays the reload. Raising context or
dropping the `q8_0` caches risks OOM at 15.9 GiB — keep `limit.context` ≤ `--ctx-size`.

Stretch only: Qwen3-Coder-30B-A3B Q4 is borderline (~18 GB) — solo slot, small
context at best. Qwen2.5-Coder-14B is the 16 GB sweet spot; 70B-class is infeasible.
