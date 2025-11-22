{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      # let pkgs = nixpkgs.legacyPackages.${system};
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            permittedInsecurePackages = [ "python-2.7.18.8" ];
          };
        };
      in {
        devShells.default = pkgs.mkShell {
          name = "elixir-env";
          buildInputs = [
            pkgs.gnumake
            pkgs.gcc
            pkgs.elixir_1_19
            pkgs.erlang
            pkgs.rebar3
            pkgs.chromedriver
            pkgs.postgresql
            pkgs.vdirsyncer
            pkgs.python27
            pkgs.python27Packages.pip
            pkgs.python313
            pkgs.claude-code
            pkgs.codex
            pkgs.uv
          ];
          env = {
            LANG = "en_US.UTF-8";
            ERL_AFLAGS = "-kernel shell_history enabled";
            MIX_ENV = "dev";
            MIX_HOME = "./.nix-mix";
            HEX_HOME = "./.nix-hex";
            MIX_REBAR3 = "${pkgs.rebar3}/bin/rebar3";
          };
          shellHook = "";

        };
      });
}
