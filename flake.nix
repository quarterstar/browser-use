{
  description = "Flake for LLaMa Factory";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";

    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      utils,
      pyproject-nix,
      ...
    }:
    utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        inherit (pkgs) lib;

        project = pyproject-nix.lib.project.loadPyproject {
          projectRoot = ./.;
        };

        runtimeLibs = with pkgs; [
          stdenv.cc.cc.lib
        ];

        python = pkgs.python3.override {
          packageOverrides = self: super: rec {
            bubus = super.buildPythonPackage rec {
              pname = "bubus";
              version = "1.5.6";
              format = "wheel";

              src = super.fetchPypi {
                inherit pname version;
                extension = "tar.gz";
                hash = "sha256-GlRW8KV26GYTp71m6BmJG2d3eDILbikQlOM5sNnfLg0=";
              };

              build-system = with self; [
                setuptools
                wheel
              ];
              dependencies = with self; [
                pydantic
                anyio
              ];
              doCheck = false;
            };

            uuid7 = super.buildPythonPackage rec {
              pname = "uuid7";
              version = "0.1.0";
              format = "wheel";

              src = super.fetchPypi {
                inherit pname version;
                format = "wheel";
                python = "py2.py3";
                dist = "py2.py3";
                hash = "sha256-XiWbtjyMtK3tWSf/QbREqA0McSTooM7Xz0TvofXMz2E=";
              };

              build-system = with self; [
                setuptools
                wheel
              ];

              doCheck = false;
            };

            cdp_use = super.buildPythonPackage rec {
              pname = "cdp-use";
              version = "1.4.5";
              format = "wheel";

              src = super.fetchPypi {
                pname = "cdp_use";
                inherit version;
                format = "wheel";
                python = "py3";
                dist = "py3";
                hash = "sha256-j44kNeOiDkAJ0pdBRBks88Ey9sKXEzjhVhmIFNm5Hss=";
              };

              build-system = with self; [
                setuptools
                wheel
              ];

              dependencies = with self; [
                typing-extensions
                httpx
                websockets
              ];

              doCheck = false;
            };

            cdp-use = cdp_use;

            browser-use-sdk = super.buildPythonPackage rec {
              pname = "browser-use-sdk";
              version = "3.4.2";
              format = "pyproject";

              src = super.fetchPypi {
                pname = "browser_use_sdk";
                inherit version;
                hash = "sha256-vgULyAOzHsTp8j39cdncXxFg197AuWIyeRXK90OhAgg=";
              };

              build-system = with self; [
                hatchling
              ];

              dependencies = with self; [
                httpx
                pydantic
              ];

              doCheck = false;
            };

            browser_use_sdk = browser-use-sdk;
          };
        };
        pythonPkgs = python.pkgs;

        package =
          let
            parsedDeps = pyproject-nix.lib.renderers.withPackages {
              inherit project python;
            };
          in
          pythonPkgs.buildPythonPackage {
            pname = project.pyproject.project.name;
            version = project.pyproject.project.version or "0.9.1";
            format = "pyproject";

            src = ./.;

            build-system = with pythonPkgs; [
              setuptools
              wheel
            ];

            dependencies = parsedDeps pythonPkgs;

            nativeBuildInputs = [
            ];

            inherit runtimeLibs;

            postFixup = ''
              if [ -e $out/bin/llamafactory-cli ]; then
                wrapProgram $out/bin/llamafactory-cli \
                  --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath runtimeLibs}"
              fi
            '';

            dontCheckRuntimeDeps = true;

            doCheck = false;
          };
      in
      {
        packages = rec {
          browser-use = package;
          default = browser-use;
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            uv
            python

            git
            # gnumake
            # gcc
          ];

          inherit runtimeLibs;
        };
      }
    );
}
