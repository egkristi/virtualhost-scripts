#!/bin/bash
set -e

if [ -z ${1} ]; then
	WATCH_FOLDER="/var/www"
else
	WATCH_FOLDER=${1}
fi
if [ -z ${2} ]; then
	TRIGGER_SCRIPT="./handle-nginx-virtualhost.sh"
else
	TRIGGER_SCRIPT=${2}
fi

monitor_folder(){
    INOTIFY_DIR=${1}
    EXECUTE_COMMAND=${2}
    PIDS_PREV_INOTIFY=$(ps -ef | grep -v grep |grep "inotifywait -m -e create,delete,moved_to,moved_from ${INOTIFY_DIR}" | awk '{print $2}')
    echo ${PIDS_PREV_INOTIFY}
    if [ ! -z "${PIDS_PREV_INOTIFY}" ]; then
        for PID_PREV_INOTIFY in $PIDS_PREV_INOTIFY
        do
            echo "Killing ${PID_PREV_INOTIFY}"
            kill -9 ${PID_PREV_INOTIFY}
        done
    fi
    inotifywait -m -e create,delete,moved_to,moved_from "${INOTIFY_DIR}" | while read WATCHED_FOLDER EVENT CHANGED
    do
		case ${EVENT} in
			"CREATE,ISDIR")
				. ${EXECUTE_COMMAND} ${WATCHED_FOLDER} ${EVENT} ${CHANGED}
			;;
			"DELETE,ISDIR")
				. ${EXECUTE_COMMAND} ${WATCHED_FOLDER} ${EVENT} ${CHANGED}
			;;
			"MOVED_TO,ISDIR")
				. ${EXECUTE_COMMAND} ${WATCHED_FOLDER} ${EVENT} ${CHANGED}
			;;
			"MOVED_FROM,ISDIR")
				. ${EXECUTE_COMMAND} ${WATCHED_FOLDER} ${EVENT} ${CHANGED}
			;;
			"CREATE")
				#. ${EXECUTE_COMMAND} ${WATCHED_FOLDER} ${EVENT} ${CHANGED}
			;;
			"DELETE")
				#. ${EXECUTE_COMMAND} ${WATCHED_FOLDER} ${EVENT} ${CHANGED}
			;;
			"MOVED_TO")
				#. ${EXECUTE_COMMAND} ${WATCHED_FOLDER} ${EVENT} ${CHANGED}
			;;
			"MOVED_FROM")
				#. ${EXECUTE_COMMAND} ${WATCHED_FOLDER} ${EVENT} ${CHANGED}
			;;
			*)
				echo "unknown inotify event"
			;;
		esac
    done
}

monitor_folder ${WATCH_FOLDER} ${TRIGGER_SCRIPT} &
