# imprison

Runs the [pi](https://pi.dev) coding agent inside an isolated [smolvm](https://github.com/smol-machines/smolvm) VM.

## Getting started

1. [Install smolvm](https://github.com/smol-machines/smolvm#install) and make sure it's on your `PATH`.
2. Start the agent for a project directory:

   ```sh
   imprison.sh <path/to/project>
   ```

   For example, to start the agent for a project located in the current directory:

   ```sh
   imprison.sh .
   ```

   This creates (if needed) and attaches to a VM for that directory, then runs `pi`.
3. Optionally configure extra packages before first creating the VM (also run at create if no configuration exists):

   ```sh
   imprison.sh config <path/to/project>
   ```

4. Other commands:

   ```sh
   imprison.sh stop <path/to/project>   # stop the machine for the specified workspace
   imprison.sh stop all                # stop every machine, no prompt
   imprison.sh list                    # list all machines and their state
   imprison.sh delete                  # prompt to pick a machine to stop and delete
   imprison.sh delete <path/to/project>  # stop and delete the machine for the specified workspace
   imprison.sh delete all               # stop and delete every machine
   imprison.sh help                     # show usage
   ```

## Supported Customizations in `imprison.config`

- `PACKAGES`: Extra dnf packages/groups to install, space-separated.
  Example: `PACKAGES="ripgrep fzf tmux"`
- `CUSTOM_PI_HOME`: Host directory mounted at `/root/.pi` in the guest.
  Default: `$HOME/.imprison/pi`
- `pre_setup()`: Placeholder function for workspace-specific setup, run before installing packages.
- `post_setup()`: Placeholder function for workspace-specific setup, run after installing packages.

## License

See [LICENSE.txt](LICENSE.txt) for details.
