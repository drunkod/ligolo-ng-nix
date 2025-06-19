{
  description = "A Ligolo-ng flake for running the proxy and agent";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        ligoloPackage = pkgs.ligolo-ng;
      in
      {
        # Packages define runnable wrapper scripts.
        packages = {
          # Package to run the Ligolo-ng proxy (server-side).
          ligolo-proxy = pkgs.writeShellScriptBin "run-ligolo-proxy" ''
            #!${pkgs.stdenv.shell}
            echo "### Starting Ligolo-ng Proxy ###"
            echo "IMPORTANT: This command must be run with root privileges (e.g., using 'sudo') to create network interfaces."
            echo "Starting proxy with a self-signed certificate on 0.0.0.0:11601."
            echo "Pass additional arguments if needed, e.g., 'sudo nix run .#proxy -- -laddr 1.2.3.4:443'"
            # The proxy requires root to create a TUN interface.
            # 'exec' replaces the shell process with the proxy process.
            # '"$@"' forwards all script arguments to the proxy binary.
            exec ${ligoloPackage}/bin/proxy -selfcert -laddr 0.0.0.0:11601 "$@"
          '';

          # Package to run the Ligolo-ng agent (client-side).
          ligolo-agent = pkgs.writeShellScriptBin "run-ligolo-agent" ''
            #!${pkgs.stdenv.shell}
            echo "### Starting Ligolo-ng Agent ###"
            if [ $# -eq 0 ]; then
                echo "ERROR: Please provide arguments."
                echo "Usage: nix run .#agent -- -connect YOUR_VPS_IP:11601 -ignore-cert"
                exit 1
            fi
            echo "Connecting to proxy..."
            # The agent does not require root privileges.
            exec ${ligoloPackage}/bin/agent "$@"
          '';

          # Expose the raw ligolo-ng package.
          ligolo-ng = ligoloPackage;
        };

        # Apps allow running packages directly with 'nix run'.
        apps = {
          proxy = {
            type = "app";
            program = "${self.packages.${system}.ligolo-proxy}/bin/run-ligolo-proxy";
          };
          agent = {
            type = "app";
            program = "${self.packages.${system}.ligolo-agent}/bin/run-ligolo-agent";
          };
        };

        # Default app to run with 'nix run .'
        defaultApp = self.apps.${system}.proxy;

        # Development shell for manual control.
        devShells.default = pkgs.mkShell {
          name = "ligolo-ng-dev-shell";
          buildInputs = [
            ligoloPackage
            pkgs.iproute2 # For 'ip addr', 'ip route' etc.
          ];
          shellHook = ''
            echo "### Ligolo-ng Development Shell ###"
            echo "The 'proxy' and 'agent' executables are in your PATH."
            echo ""
            echo "Example Commands:"
            echo "  Server (on VPS): sudo proxy -selfcert"
            echo "  Client (local):  agent -connect YOUR_VPS_IP:11601 -ignore-cert"
            echo ""
          '';
        };

        # Standard formatter for 'nix fmt'.
        formatter = pkgs.nixpkgs-fmt;
      }
    );
}