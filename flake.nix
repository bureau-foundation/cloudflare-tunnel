# Copyright 2026 The Bureau Authors
# SPDX-License-Identifier: Apache-2.0

{
  description = "Cloudflare Tunnel template for Bureau — routes external traffic to internal services";

  nixConfig = {
    extra-substituters = [ "https://cache.infra.bureau.foundation" ];
    extra-trusted-public-keys = [
      "cache.infra.bureau.foundation-1:3hpghLePqloLp0qMpkgPy/i0gKiL/Sxl2dY8EHZgOeY= cache.infra.bureau.foundation-2:e1rDOXBK+uLDTT+YU2UzIzkNHpLEaG2jCHZumlH1UmY="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages.default = pkgs.cloudflared;

        # Bureau template definition. The `bureau template publish --flake`
        # command evaluates this attribute and publishes it as a Matrix state
        # event. Field names use snake_case matching the TemplateContent JSON
        # wire format (lib/schema/events_template.go).
        #
        # The command path resolves to a full /nix/store/... path at eval
        # time. The daemon prefetches missing store paths from the binary
        # cache before creating the sandbox.
        bureauTemplate = {
          description = "Cloudflare Tunnel for routing external traffic to Bureau services via connector token";
          inherits = [ "bureau/template:base-networked" ];
          command = [ "${pkgs.cloudflared}/bin/cloudflared" "tunnel" "run" ];
          # The environment store path is bind-mounted into the sandbox
          # at /nix/store (read-only), and its bin/ is prepended to PATH.
          # cloudflared is dynamically linked (glibc, etc.), so the full
          # Nix closure must be available — a single-binary bind-mount
          # is not sufficient.
          environment = "${pkgs.cloudflared}";
        };
      }
    );
}
