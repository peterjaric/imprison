#!/usr/bin/env bash

#####
#
# Run Pi inside a VM.
#
# If the smolfile has changed, delete the machine first so it is recreated.
#
#####

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: imprison.sh <start [cmd]|stop [all]|delete [all]|list|config|help>

  start [cmd]  Create/start the machine for the current workspace directory
               and attach interactively, running cmd (default: pi).
  stop         Stop the machine for the current workspace directory.
  stop all     Stop every machine this tool created.
  delete       List all machines this tool created and prompt for one to
               stop (if running) and delete.
  delete all   Prompt once, then stop (if running) and delete every machine
               this tool created.
  list         List all machines this tool created, with running state.
  config       Interactively select extra packages and write them to
               imprison.config in the current workspace directory.
  help         Show this help message.

imprison.config:
  Optional, at the root of the workspace directory. Sourced as shell on VM
  init (setup.sh), so it's read only the first time a machine is created.
  Supported variables:
    PACKAGES  Extra dnf packages/groups to install, space-separated.
              Example: PACKAGES="ripgrep fzf tmux"
    CUSTOM_PI_HOME  Host directory mounted at /root/.pi in the guest.
                    Default: $HOME/.imprison/pi
  Use imprison.sh config to interactively create this file.
EOF
}

subcommand="${1:-}"

script_path="$(readlink -f "${BASH_SOURCE[0]}")"
workspace_dir="$PWD"

case "$subcommand" in
  start|stop|delete|list|config)
    tool_dir="$(cd "$(dirname "$script_path")" && pwd)"
    cd "$tool_dir"
    . ./host/vm.sh
    if [[ "$subcommand" == "start" ]] || { [[ "$subcommand" == "stop" ]] && [[ "${2:-}" != "all" ]]; }; then
      name="$(vm_machine_name "$workspace_dir")"
    fi
    ;;
  ""|help)
    usage
    exit 0
    ;;
  *)
    usage
    exit 1
    ;;
esac

case "$subcommand" in
  start)
    if ! vm_is_under_code_dir "$workspace_dir"; then
      echo "Warning: '$workspace_dir' is not under \$HOME/code." >&2
      read -r -p "Continue anyway? [y/N] " reply
      case "$reply" in
        [yY]|[yY][eE][sS]) ;;
        *) echo "Aborted." >&2; exit 1 ;;
      esac
    fi

    if ! vm_exists "$name"; then
      if [[ ! -e "$workspace_dir/imprison.config" ]]; then
        read -r -p "No imprison.config found. Configure packages before creating the VM? [y/N] " reply
        case "$reply" in
          [yY]) vm_write_config "$workspace_dir" ;;
        esac
      fi
      vm_create "$name" "$workspace_dir"
    fi

    if ! vm_is_running "$name"; then
      vm_start "$name"
    fi

    vm_wait_ready "$name"

    vm_attach "$name" "$workspace_dir" "${2:-pi}"
    ;;

  stop)
    if [[ "${2:-}" == "all" ]]; then
      vm_stop_all
    else
      vm_stop "$name"
    fi
    ;;

  delete)
    if [[ "${2:-}" == "all" ]]; then
      vm_delete_all
      exit 0
    fi
    if ! name="$(vm_select_machine)"; then
      exit 0
    fi
    read -r -p "Delete machine '$name'? [y/N] " reply
    case "$reply" in
      [yY]|[yY][eE][sS]) ;;
      *) echo "Aborted." >&2; exit 0 ;;
    esac
    vm_delete "$name"
    ;;

  list)
    vm_list
    ;;

  config)
    vm_write_config "$workspace_dir"
    ;;
esac
