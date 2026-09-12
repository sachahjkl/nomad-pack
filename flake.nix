{
  description = "Generic Nomad Pack for homelab applications";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.2605";
    git-hooks = {
      url = "https://flakehub.com/f/cachix/git-hooks.nix/0.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    nixpkgs,
    git-hooks,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfreePredicate = package: nixpkgs.lib.getName package == "nomad";
    };
    pack = pkgs.runCommand "homelab-nomad-pack" {} ''
      mkdir -p "$out/templates"
      cp ${./metadata.hcl} "$out/metadata.hcl"
      cp ${./variables.hcl} "$out/variables.hcl"
      cp ${./templates/application.nomad.tpl} "$out/templates/application.nomad.tpl"
    '';
    preCommitCheck = git-hooks.lib.${system}.run {
      package = pkgs.prek;
      src = ./.;
      hooks = {
        alejandra.enable = true;
        check-added-large-files.enable = true;
        check-merge-conflicts.enable = true;
        end-of-file-fixer.enable = true;
        trim-trailing-whitespace.enable = true;
      };
    };
    packCheck = pkgs.runCommand "homelab-nomad-pack-check" {nativeBuildInputs = [pkgs.nomad pkgs.nomad-pack];} ''
      export HOME="$TMPDIR"
      cat >vars.hcl <<'EOF'
      name = "example"
      domain = "example.sacha.house"
      environment = "staging"
      health_path = "/health"
      image = "ghcr.io/sachahjkl/example@sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
      port = 8080
      service_tags = []
      volume_enabled = false
      volume_mount_path = ""
      volume_name = ""
      EOF
      nomad-pack render ${pack} --var-file vars.hcl --to-dir rendered --auto-approve >/dev/null
      nomad job validate rendered/homelab-application/application.nomad
      touch "$out"
    '';
  in {
    packages.${system}.default = pack;
    checks.${system} = {
      default = packCheck;
      pre-commit = preCommitCheck;
    };
    formatter.${system} = pkgs.alejandra;
    devShells.${system}.default = pkgs.mkShell {
      packages = preCommitCheck.enabledPackages ++ [pkgs.nomad pkgs.nomad-pack];
      inherit (preCommitCheck) shellHook;
    };
  };
}
