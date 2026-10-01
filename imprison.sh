#!/usr/bin/env bash

# Run Pi inside a VM. See README.md for usage and configuration details.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: imprison.sh <path [cmd]|stop <path|all>|delete [path|all]|list|config <path>|help>

  <path> [cmd] Create/start the machine for the workspace directory at <path>
               and attach interactively, running cmd (default: pi).
  stop <path>  Stop the machine for the workspace directory at <path>.
  stop all     Stop every machine this tool created.
  delete [path] List all machines this tool created and prompt for one to
               stop (if running) and delete; if <path> is given, stop
               (if running) and delete that workspace directory's machine
               directly, after confirmation.
  delete all   Prompt once, then stop (if running) and delete every machine
               this tool created.
  list         List all machines this tool created, with running state.
  config <path> Interactively select extra packages and write them to
               imprison.config in the workspace directory at <path>.
  help         Show this help message.

imprison.config:
  Optional, at the root of the workspace directory. Sourced as shell on VM
  init (setup.sh), so it's read only the first time a machine is created.
  Supported variables:
    PACKAGES  Extra dnf packages/groups to install, space-separated.
              Example: PACKAGES="ripgrep fzf tmux"
    CUSTOM_PI_HOME  Host directory mounted at /root/.pi in the guest.
                    Default: $HOME/.imprison/pi
  Use imprison.sh config <path> to interactively create this file.
EOF
}

first_arg="${1:-}"
script_path="$(readlink -f "${BASH_SOURCE[0]}")"

# Resolve a workspace path argument to an absolute directory.
# If require_exists is "1", fail unless the directory already exists.
resolve_workspace_dir() {
  local path="$1"
  local require_exists="${2:-1}"
  if [[ "$require_exists" == "1" ]] && [[ ! -d "$path" ]]; then
    echo "Workspace directory '$path' does not exist." >&2
    exit 1
  fi
  readlink -f "$path"
}

case "$first_arg" in
  stop|delete|list|config)
    subcommand="$first_arg"
    ;;
  ""|help)
    usage
    exit 0
    ;;
  *)
    subcommand="start"
    ;;
esac

tool_dir="$(cd "$(dirname "$script_path")" && pwd)"
cd "$tool_dir"
. ./host/vm.sh

# Determine the path argument (if any) for the chosen subcommand.
path_arg=""
case "$subcommand" in
  start) path_arg="$first_arg" ;;
  stop|delete|config) path_arg="${2:-}" ;;
esac

if [[ -z "$path_arg" ]] && [[ "$subcommand" == "start" || "$subcommand" == "stop" || "$subcommand" == "config" ]]; then
  echo "Usage: imprison.sh <path [cmd]|stop <path|all>|delete [path|all]|list|config <path>|help>" >&2
  exit 1
fi

# Resolve the workspace directory and machine name once, unless the path
# argument is the special "all" value (handled separately below) or absent
# (e.g. "delete" with no path, which falls back to interactive selection).
if [[ -n "$path_arg" ]] && [[ "$path_arg" != "all" ]]; then
  require_exists=0
  if [[ "$subcommand" == "start" || "$subcommand" == "config" ]]; then
    require_exists=1
  fi
  workspace_dir="$(resolve_workspace_dir "$path_arg" "$require_exists")"
  name="$(vm_machine_name "$workspace_dir")"
fi

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
    if [[ "$path_arg" == "all" ]]; then
      vm_stop_all
    else
      vm_stop "$name"
    fi
    ;;

  delete)
    if [[ "$path_arg" == "all" ]]; then
      vm_delete_all
      exit 0
    fi
    if [[ -z "$path_arg" ]] && ! name="$(vm_select_machine)"; then
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
