#!/bin/bash
set -euo pipefail

WATCH_FOLDER="${1:-/var/www}"
TRIGGER_SCRIPT="${2:-$(dirname "$0")/handle-nginx-virtualhost.sh}"

if [ ! -d "${WATCH_FOLDER}" ]; then
	echo "Error: Watch folder does not exist: ${WATCH_FOLDER}" >&2
	exit 1
fi

if [ ! -f "${TRIGGER_SCRIPT}" ]; then
	echo "Error: Trigger script not found: ${TRIGGER_SCRIPT}" >&2
	exit 1
fi

if ! command -v inotifywait &>/dev/null; then
	echo "Error: inotifywait not found. Install inotify-tools:" >&2
	echo "  apt-get install inotify-tools" >&2
	exit 1
fi

monitor_folder() {
	local INOTIFY_DIR="$1"
	local EXECUTE_COMMAND="$2"

	# Kill any existing inotifywait process watching the same directory
	if command -v pgrep &>/dev/null; then
		pgrep -f "inotifywait.*${INOTIFY_DIR}" | while read -r PID; do
			echo "Stopping existing watcher (PID ${PID})"
			kill "${PID}" 2>/dev/null || true
		done
		sleep 1
	fi

	echo "Watching ${INOTIFY_DIR} for directory changes..."
	inotifywait -m -e create,delete,moved_to,moved_from "${INOTIFY_DIR}" |
		while read -r WATCHED_FOLDER EVENT CHANGED; do
			case "${EVENT}" in
				"CREATE,ISDIR"|"DELETE,ISDIR"|"MOVED_TO,ISDIR"|"MOVED_FROM,ISDIR")
					echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${EVENT}: ${CHANGED}"
					bash "${EXECUTE_COMMAND}" "${WATCHED_FOLDER}" "${EVENT}" "${CHANGED}"
					;;
				*)
					# Ignore non-directory events silently
					;;
			esac
		done
}

monitor_folder "${WATCH_FOLDER}" "${TRIGGER_SCRIPT}" &
echo "Monitor started in background (PID $!)"
