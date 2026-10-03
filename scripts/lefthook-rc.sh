# Sourced by lefthook before every job (see `rc` in lefthook.yml).
#
# GUI git clients (Fork, Tower, VS Code's Git panel, ...) are launched from the
# Dock with the minimal macOS PATH, so Flutter and Dart are missing in hooks.
# When that happens, borrow PATH from the user's own shell startup files.

if ! command -v flutter >/dev/null 2>&1; then
  user_shell=${SHELL:-/bin/zsh}
  # -i -l reads both login and interactive startup files (.zprofile and .zshrc);
  # markers separate PATH from anything those files print.
  shell_path=$("$user_shell" -ilc 'printf "\n__PATH__%s__PATH__\n" "$PATH"' 2>/dev/null </dev/null |
    sed -n 's/^__PATH__\(.*\)__PATH__$/\1/p' | tail -n 1)
  if [ -n "$shell_path" ]; then
    PATH="$shell_path:$PATH"
    export PATH
  fi
  unset user_shell shell_path
fi
