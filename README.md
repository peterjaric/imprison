# imprison

Runs the [pi](https://pi.dev) coding agent inside an isolated [smolvm](https://github.com/smol-machines/smolvm) VM, one machine per workspace directory, with the workspace mounted at `/workspace`.

## Getting started

1. [Install smolvm](https://github.com/smol-machines/smolvm#install) and make sure it's on your `PATH`.
2. From your project directory, start the agent:

   ```sh
   imprison.sh start
   ```

   This creates (if needed) and attaches to a VM for the current directory, then runs `pi`.
3. Optionally configure extra packages before first creating the VM (also run at create if no configuration exists):

   ```sh
   imprison.sh config
   ```

4. Other commands:

   ```sh
   imprison.sh stop       # stop the machine for this workspace
   imprison.sh stop all   # stop every machine, no prompt
   imprison.sh list       # list all machines and their state
   imprison.sh delete     # stop and delete a machine
   imprison.sh delete all # stop and delete every machine, one y/N prompt
   imprison.sh help       # show usage
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
