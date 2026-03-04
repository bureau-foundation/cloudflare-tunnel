# Agent Guide

This is a single-file Nix flake that packages `cloudflared` as a Bureau
template. There is no Go code, no build system beyond Nix, and no tests
beyond CI validation.

## Repository structure

- `flake.nix` — the entire package definition. Exports `packages.default`
  (cloudflared binary) and `bureauTemplate` (Bureau template attributes).
- `.github/workflows/ci.yaml` — builds the flake, validates the template
  output, and pushes to the R2 binary cache on merge to main.
- `README.md` — deployment guide for operators.

## Making changes

Edit `flake.nix`. Run `nix build` to verify it builds, and
`nix eval --json .#bureauTemplate.x86_64-linux` to verify the template output.
Update `flake.lock` with `nix flake update` if changing inputs.

The `bureauTemplate` output must use snake_case field names matching Bureau's
`TemplateContent` JSON wire format. See the Bureau monorepo's
`lib/schema/events_template.go` for the full field list.
