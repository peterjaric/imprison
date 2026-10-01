#!/usr/bin/env bash

# Shared helpers for managing per-workspace smolvm agent machines.

MACHINE_PREFIX="agent-"
SMOLFILE="host/agent.smolfile"
CUSTOM_PI_HOME="${CUSTOM_PI_HOME:-$HOME/.imprison/pi}"

# Host DNS resolver to forward into the guest (some networks block public DNS).
vm_dns_server() {
  resolvectl status | awk '/Current DNS Server:/ { print $NF; exit }'
}

# Compute the machine name for a workspace directory.
vm_machine_name() {
  local workspace_dir="${1:?workspace_dir required}"
  local base parent
  base="$(basename "$workspace_dir")"
  parent="$(basename "$(dirname "$workspace_dir")")"
  local name
  if [[ "$workspace_dir" == "/" || "$parent" == "/" ]]; then
    name="${MACHINE_PREFIX}${base}"
  else
    name="${MACHINE_PREFIX}${parent}-${base}"
  fi
  echo "${name,,}"
}

# True if the workspace directory is inside $HOME.
vm_is_under_home() {
  local workspace_dir="${1:?workspace_dir required}"
  local home="${HOME%/}"
  case "$workspace_dir" in
    "$home"/*|"$home") return 0 ;;
    *) return 1 ;;
  esac
}

# Print the machine's structured status.
vm_status_json() {
  local name="$1"
  smolvm machine status --name "$name" --json
}

# True if the machine has been created.
vm_exists() {
  local name="$1"
  smolvm machine status --name "$name" >/dev/null 2>&1
}

# True if the machine is currently running.
vm_is_running() {
  local name="$1"
  local status
  status="$(vm_status_json "$name" 2>/dev/null)" || return 1
  [[ "$status" == *'"state": "running"'* ]]
}

# Block until the machine accepts exec commands, or fail after ~60s.
vm_wait_ready() {
  local name="$1"
  local attempt
  for attempt in {1..60}; do
    if smolvm machine exec --name "$name" -- true >/dev/null 2>&1; then
      return 0
    fi
    if (( attempt == 60 )); then
      echo "Timed out waiting for the VM to accept commands." >&2
      return 1
    fi
    sleep 1
  done
}

# Create the machine from the project's Smolfile, mounting the workspace and Pi home.
vm_create() {
  local name="$1"
  local workspace_dir="$2"
  local pi_home="$CUSTOM_PI_HOME"
  local config_file="$workspace_dir/imprison.config"

  if [[ -f "$config_file" ]]; then
    pi_home="$(source "$config_file"; printf '%s' "${CUSTOM_PI_HOME:-$pi_home}")"
  fi

  if [[ "$pi_home" == "$CUSTOM_PI_HOME" ]]; then
    mkdir -p "$pi_home"
  fi

  local guest_dir
  guest_dir="/$(basename "$workspace_dir")"

  local volumes=(
    --volume "$workspace_dir:$guest_dir"
    --volume "$pi_home:/root/.pi"
  )

  # Mount the .git directory as read-only to prevent modifications by the agent
  if [[ -e "$workspace_dir/.git" ]]; then
    volumes+=(--volume "$workspace_dir/.git:$guest_dir/.git:ro")
  fi

  smolvm machine create --name "$name" -s "$SMOLFILE" \
    --dns "$(vm_dns_server)" \
    --workdir "$guest_dir" \
    --env "WORKSPACE_DIR=$guest_dir" \
    "${volumes[@]}"
}

# Boot a stopped machine.
vm_start() {
  local name="$1"
  smolvm machine start --name "$name"
}

# Attach interactively and run the given command (default: pi) as the workspace owner.
vm_attach() {
  local name="$1"
  local workspace_dir="$2"
  # Shift past the first two arguments (name and workspace_dir) to leave any additional command
  # arguments in "$@" that is passed to the launch-agent script.
  shift 2
  local guest_dir="/$(basename "$workspace_dir")"
  exec smolvm machine exec -it --name "$name" -w "$guest_dir" -- /scripts/launch-agent.sh "${@:-pi}"
}

# Machine names this tool created, one per line (empty if none).
vm_list_names() {
  smolvm machine ls --quiet | grep "^${MACHINE_PREFIX}" | sort || true
}

# Print every machine this tool created, with running state.
vm_list() {
  local names
  names="$(vm_list_names)"
  if [[ -z "$names" ]]; then
    echo "No machines found."
    return 0
  fi

  local n
  while IFS= read -r n; do
    if vm_is_running "$n"; then
      echo "$n  [running]"
    else
      echo "$n  [stopped]"
    fi
  done <<< "$names"
}

# Interactive machine selection helper.
# Prompt the user to pick one of this tool's machines from a numbered menu.
# Echoes the chosen machine name on success; returns 1 if none exist.
vm_select_machine() {
  local names
  names="$(vm_list_names)"
  if [[ -z "$names" ]]; then
    echo "No machines found." >&2
    return 1
  fi

  local machine_names menu n choice
  mapfile -t machine_names <<< "$names"
  menu=()
  for n in "${machine_names[@]}"; do
    if vm_is_running "$n"; then
      menu+=("$n  running")
    else
      menu+=("$n  stopped")
    fi
  done

  echo "Select a machine:" >&2
  select choice in "${menu[@]}"; do
    if [[ -n "$choice" ]]; then
      echo "${machine_names[$((REPLY - 1))]}"
      return 0
    fi
    echo "Invalid selection." >&2
  done
}

# Stop a machine if it's running; report if it doesn't exist or is already stopped.
vm_stop() {
  local name="$1"
  if ! vm_exists "$name"; then
    echo "Machine '$name' does not exist."
    return 0
  fi
  if ! vm_is_running "$name"; then
    echo "Machine '$name' is already stopped."
    return 0
  fi
  smolvm machine stop --name "$name"
}

# Stop every machine this tool created, without prompting.
vm_stop_all() {
  local names
  names="$(vm_list_names)"
  if [[ -z "$names" ]]; then
    echo "No machines found."
    return 0
  fi

  local n
  while IFS= read -r n; do
    vm_stop "$n"
  done <<< "$names"
}

# Stop (if running) and delete a single machine.
vm_delete() {
  local name="$1"
  if vm_is_running "$name"; then
    smolvm machine stop --name "$name"
  fi
  smolvm machine delete --name "$name" --force
}

# Prompt once, then stop (if running) and delete every machine this tool created.
vm_delete_all() {
  local names
  names="$(vm_list_names)"
  if [[ -z "$names" ]]; then
    echo "No machines found."
    return 0
  fi

  read -r -p "Delete all machines? [y/N] " reply
  case "$reply" in
    [yY]|[yY][eE][sS]) ;;
    *) echo "Aborted." >&2; return 0 ;;
  esac

  local n
  while IFS= read -r n; do
    vm_delete "$n"
  done <<< "$names"
}

# Interactively select extra packages and write them to imprison.config.
vm_write_config() {
  local workspace_dir="${1:?workspace_dir required}"
  local common_packages=(
    java-25-openjdk-devel
    mvn
    ruby
    python3
  )

  echo "Select packages to install (space-separated numbers):"
  local i
  for i in "${!common_packages[@]}"; do
    printf '  %2d) %s\n' "$((i + 1))" "${common_packages[$i]}"
  done
  local selection
  read -r -p "> " selection

  local selected=() n
  for n in $selection; do
    if [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#common_packages[@]} )); then
      selected+=("${common_packages[$((n - 1))]}")
    fi
  done

  local config_file="$workspace_dir/imprison.config"
  cat > "$config_file" <<EOF
# Generated by imprison.sh config

# Extra packages to install via dnf (space-separated)
PACKAGES="${selected[*]}"

# Host directory mounted at /root/.pi in the guest
CUSTOM_PI_HOME="$HOME/.imprison/pi"

# Custom setup hook run before packages are installed
pre_setup() {
  :
}

# Custom setup hook run after packages are installed
post_setup() {
  :
}
EOF
  echo "Wrote $config_file"
}

