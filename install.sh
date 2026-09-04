#!/bin/sh
set -e

# Repository Configuration
OWNER="EnterpriseDB"
REPO="kubectl-cnp-diagnostic"
# This MUST start with kubectl- to be recognized as a plugin
BINARY="kubectl-edbdiag"

# No-sudo by design: on many corporate-managed Macs, invoking `sudo` triggers
# an MDM/endpoint-security elevation prompt (e.g. a GUI "Launch with elevated
# privileges" dialog) that never surfaces properly through a piped
# `curl | sudo sh` install, leaving the install permanently stuck with no
# output and no visible prompt. To avoid that entirely, this script never
# calls sudo. It installs into the current user's own bin directory instead
# of a system path that requires root.
#
# Guard against being run with sudo anyway (e.g. out of habit from an old
# README/browser-history command): if invoked as root, `whoami` resolves to
# "root" and everything below would silently install into /var/root instead
# of the real user's home - invisible to that user's own shell afterwards.
# Refuse early with a clear message instead of failing confusingly later.
if [ "$(id -u)" = "0" ]; then
    echo "ERROR: Do not run this installer with sudo." >&2
    echo "       It installs into your own user directory (~/.local/bin) and needs" >&2
    echo "       no elevated privileges. Re-run it as your normal user, e.g.:" >&2
    echo "         curl -sSfL https://github.com/$OWNER/$REPO/raw/main/install.sh | sh" >&2
    exit 1
fi

TARGET_USER="$(whoami)"
TARGET_HOME=$(eval echo "~${TARGET_USER}")
INSTALL_PATH="${TARGET_HOME}/.local/bin"
mkdir -p "$INSTALL_PATH"

echo "Installing $BINARY from $OWNER/$REPO..."

# 1. Fetch the tool via `git clone` rather than curl-ing
#    raw.githubusercontent.com directly. Some corporate SSL-inspecting
#    proxies (e.g. Netskope) block or silently hang on direct
#    raw.githubusercontent.com requests - with or without HTTP/2 - while
#    git's smart-HTTP protocol against github.com itself goes through fine.
#    --depth 1 keeps this fast and avoids pulling full history.
if ! command -v git >/dev/null 2>&1; then
    echo "git is required to install this plugin. Please install git and re-run." >&2
    exit 1
fi

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

git clone --depth 1 --quiet "https://github.com/$OWNER/$REPO.git" "$TMP_DIR/$REPO"

if [ ! -f "$TMP_DIR/$REPO/$BINARY" ]; then
    echo "Could not find $BINARY in the cloned repository." >&2
    exit 1
fi

# Stay entirely inside $TMP_DIR for this - never touch a file named
# "$BINARY" in the current working directory. If this script is run from
# inside a clone of this same repo (which already has a tracked file with
# this exact name), copying/moving through "./$BINARY" would overwrite and
# then relocate that tracked file out of the repo entirely.
cp "$TMP_DIR/$REPO/$BINARY" "$TMP_DIR/$BINARY"

# 2. Make it executable
chmod +x "$TMP_DIR/$BINARY"

# 3. Move into the user's own bin directory - no sudo, no elevation prompt.
mv "$TMP_DIR/$BINARY" "$INSTALL_PATH/"

# 4. Make sure $INSTALL_PATH is actually on PATH so both `kubectl edbdiag`
#    (plugin form) and a bare `kubectl-edbdiag` (direct form) work without
#    typing the full path.

# NEEDS_RESTART tracks whether *this* shell's PATH is missing the install
# directory. A script run via `curl | sh` executes in a throwaway subshell -
# nothing it does to PATH, or to a *ancestor* shell's environment, and it
# can carry back into the interactive shell that invoked it. That is a hard
# limitation of how Unix processes work, not something any installer (this
# one, homebrew, rustup, nvm, etc.) can bypass. The best we can do is make
# sure the one-time "open a new terminal" step is impossible to miss.
NEEDS_RESTART=false
SHELL_RC=""

case ":${PATH}:" in
    *":${INSTALL_PATH}:"*)
        # Already on PATH for this session - nothing to do.
        ;;
    *)
        NEEDS_RESTART=true
        USER_SHELL_NAME=$(basename "${SHELL:-/bin/bash}")
        case "$USER_SHELL_NAME" in
            zsh)  SHELL_RC="${TARGET_HOME}/.zshrc" ;;
            bash)
                if [ -f "${TARGET_HOME}/.bash_profile" ]; then
                    SHELL_RC="${TARGET_HOME}/.bash_profile"
                else
                    SHELL_RC="${TARGET_HOME}/.bashrc"
                fi
                ;;
            *) SHELL_RC="${TARGET_HOME}/.profile" ;;
        esac

        if [ -f "$SHELL_RC" ] && grep -qs "$INSTALL_PATH" "$SHELL_RC" 2>/dev/null; then
            : # already configured previously - still needs a restart, see below
        else
            echo "export PATH=\"${INSTALL_PATH}:\$PATH\"" >> "$SHELL_RC"
        fi
        ;;
esac

echo "Installation successful!"

# Put the PATH warning LAST and make it loud - it's easy to scroll past a
# one-line note buried above other output, and every tester who has hit
# "command not found" right after installing simply kept typing in the same
# terminal instead of restarting it. This is the final thing printed so it's
# the thing people actually read.
if [ "$NEEDS_RESTART" = true ]; then
    echo ""
    echo "############################################################"
    echo "#  ACTION NEEDED before 'kubectl edbdiag' will work:        "
    echo "#  This terminal window can't see the updated PATH yet.     "
    echo "#  Open a NEW terminal window/tab, OR run:                  "
    echo "#      source ${SHELL_RC}"
    echo "############################################################"
    echo ""
else
    echo "Run it using: kubectl edbdiag  (or just: kubectl-edbdiag)"
fi
