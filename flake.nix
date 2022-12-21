{
  description = "schraderz mattermost deployment";
  inputs = {
    devshell.url = "github:numtide/devshell";
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:nixos/nixpkgs";
    terranix.url = "github:terranix/terranix";
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
      project = "mattermost";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ devshell.overlay ];
      };
      tf = rec {
        config = terranix.lib.terranixConfiguration {
          inherit system;
          modules = [ ./infra/config.nix ];
        };
        commandToApp = command: {
          type = "app";
          program = toString (pkgs.writers.writeBash "${command}" ''
            result="config.tf.json"
            [[ -e $result ]] && rm -f $result
            cp ${config} $result
            export GOOGLE_APPLICATION_CREDENTIALS=$(pwd)/keys/application_default_credentials.json
            terraform init
            terraform ${command}
          '');
        };
      };
    in
    rec {
      packages.tf = tf.config;
      packages.default = packages.tf;

      apps = pkgs.lib.genAttrs [ "apply" "plan" "destroy" ] tf.commandToApp;

      devShell = pkgs.devshell.mkShell {
        name = "${project}-shell";
        commands = [{ package = "devshell.cli"; }];
        packages = with pkgs; [
          gitleaks
          go
          google-cloud-sdk
          kubectl
          kubernetes-helm
          nixpkgs-fmt
          pre-commit
          terraform
          terranix
          tfsec
        ];
      };
    }
    );
}
