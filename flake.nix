{
  description = "Bunkbed backbone infrastructure";
  inputs = {
    devshell.url = github:numtide/devshell;
    flake-utils.url = github:numtide/flake-utils;
    nixpkgs.url = github:nixos/nixpkgs;
    terranix.url = github:terranix/terranix;
    terranix.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs =
    inputs@{ self
    , devshell
    , flake-utils
    , nixpkgs
    , terranix
    }: flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          devshell.overlay
          (final: prev: { lib = prev.lib // { backbone = import ./infra/lib { pkgs = final; }; }; })
        ];
      };
      x = pkgs.lib.backbone.subTemplateCmds {
        template = ./bin/x;
        cmds.bash = "${pkgs.bash}/bin/bash";
        cmds.terraform = "${pkgs.terraform}/bin/terraform";
      };
    in
    rec {
      packages.default = terranix.lib.terranixConfiguration {
        inherit system pkgs;
        modules = [
          ./infra/modules/traefik.nix
          {
            provider.kubernetes = { config_path = "/root/.kube/config"; };
            resource.kubernetes_namespace.test = { metadata.name = "test"; };
          }
        ];
      };

      apps.default = self.outputs.devShells.${system}.default.flakeApp;

      devShell = pkgs.devshell.mkShell ({ ... }: {
        name = "BACKBONE";
        commands = [ { name = "x"; command = x; } ];
        packages = with pkgs; [
          bash
          gitleaks
          go
          kubectl
          kubernetes-helm
          nixpkgs-fmt
          pre-commit
          shellcheck
          terraform
          terraform-docs
          terranix
          tfsec
        ];
      });
    }
  );
}
