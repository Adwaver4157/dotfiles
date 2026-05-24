# <parent> — multi-project workspace

This directory holds several related projects. Read this before planning any
cross-project change. (Copy this file to your parent dir as `CLAUDE.md` and fill
in the blanks.)

## Projects

| Dir | What it is | Docker? | Build / test | Key entrypoints / image |
|-----|-----------|---------|--------------|--------------------------|
| `project-a/` | <one line> | no | `uv run pytest` | <module/cli> |
| `project-b/` | <one line> | yes (GPU training) | `docker compose -f project-b/docker-compose.yml ...` | image: `projb-train:latest` |
| `project-c/` | <one line> | occasional (`docker compose up` for a local DB) | `npm test` | <...> |

## How they connect

- <project-a produces X consumed by project-b …>
- <shared schema / API contract lives in …>
- <version / compatibility constraints …>

## Cross-project conventions

- Change a shared contract in one place and update all consumers in the **same task**.
- Commit per-repo (each project is its own git repo); **push is manual**.
- Run Docker only for the ops that need it (see the table). Prefer **rootless Docker**.

## Running Claude here

- Launch `claude` in this parent dir in **auto mode**. Use the agent-team workflow
  for changes touching ≥3 files or ≥2 projects (planner surveys all projects, then
  per-project implementers + reviewer + smoke-tester).
- Heavy single-project ops (training) → run inside that project's **ml-gpu container**.
- Do **NOT** use `--dangerously-skip-permissions` on the host (no container boundary;
  it also disables the deny list). Stay in auto mode.
