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
            echo "### Starting Ligolo-ng Proxy in Daemon Mode ###"

            # Check for root privileges, as they are required.
            if [ "$(id -u)" -ne 0 ]; then
                echo "ERROR: This command must be run with root privileges (e.g., using 'sudo')."
                exit 1
            fi

            echo "Starting proxy with a self-signed certificate on 0.0.0.0:11601."
            echo "The process will run in the background."
            echo "Use 'ps aux | grep proxy' to see the running process."
            echo "Use 'ss -tulpn | grep 11601' to check the listening port."

            # The '-daemon' flag runs the proxy as a background process.
            # '"$@"' forwards all script arguments to the proxy binary.
            exec ${ligoloPackage}/bin/proxy -daemon -selfcert -laddr 0.0.0.0:11601 "$@"
          '';

          # Package to run the Ligolo-ng agent (client-side).
          ligolo-agent = pkgs.writeShellScriptBin "run-ligolo-agent" ''
            #!${pkgs.stdenv.shell}
            echo "### Starting Ligolo-ng Agent ###"
            if [ $# -eq 0 ]; then
                echo "ERROR: Please provide connection arguments." >&2
                echo "Usage: nix run .#agent -- -connect YOUR_VPS_IP:11601 -ignore-cert"
                exit 1
            fi
            echo "Connecting to proxy with arguments: $@"
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
            pkgs.procps  # For 'ps'
            pkgs.iputils # For 'ss'
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