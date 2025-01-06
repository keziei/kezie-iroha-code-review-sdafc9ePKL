#!/bin/bash
#
# program name: gg_process_status.sh
# May 25 2024 kiroha 
# This script will check the if all the replicat/extract process are alive, if it find any process stopped or abended will show error

LD_LIBRARY_PATH=$1
GG_HOME=$2

# Validate input parameters
if [ -z "$LD_LIBRARY_PATH" ]; then
    echo "status=ERROR"
    echo "ERROR: Missing LD_LIBRARY_PATH as the first parameter."
    exit 1
fi

if [ -z "$GG_HOME" ]; then
    echo "status=ERROR"
    echo "ERROR: Missing GG_HOME as the second parameter."
    exit 1
fi

# Set environment variables
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH
export PATH=$GG_HOME:$PATH

# Set temporary directories based on GG version
if [[ "$GG_HOME" = *"11"* ]]; then
    gg_tmp_dir='/tmp/gglog'
else
    gg_tmp_dir='/tmp/gglog19'
fi
export gg_tmp_dir

# Create temporary directory if it doesn't exist
if [ ! -d "$gg_tmp_dir" ]; then
    mkdir -p "$gg_tmp_dir"
fi

# Log files
EXTRACT_LIST="$gg_tmp_dir/status_extractjobs_$$.out"
HISTORICAL_LOG="$gg_tmp_dir/historical_log_$$.log"
RUNNING_LOG="$gg_tmp_dir/ggprocess_running_$$.log"
ERROR_LOG="$gg_tmp_dir/ggprocess_running_err_$$.log"

# Initialize status
status="OK"

# Function to scan and log the process status
scan_for_process() {
    $GG_HOME/ggsci <<EOF > "$EXTRACT_LIST"
info all
EOF

    if grep -q "ERROR" "$EXTRACT_LIST" || grep -q "Permission denied" "$EXTRACT_LIST"; then
        echo "ERROR: Failed to execute GGSCI command." >> "$ERROR_LOG"
        status="ERROR"
    fi

    $GG_HOME/ggsci <<EOF > "$HISTORICAL_LOG"
info *
EOF

    if grep -q "ERROR" "$HISTORICAL_LOG" || grep -q "Permission denied" "$HISTORICAL_LOG"; then
        echo "ERROR: Failed to execute GGSCI command." >> "$ERROR_LOG"
        status="ERROR"
    fi

    EXTRACT=$(awk '/EXTRACT|REPLICAT/ {print $2","$3}' "$EXTRACT_LIST")

    for extract in $EXTRACT; do
        director=$(echo $extract | cut -d ',' -f1)
        process_name=$(echo $extract | cut -d ',' -f2)

        if [ "$director" = "RUNNING" ]; then
            echo "GG Process is running: $process_name as of $(date)" >> "$RUNNING_LOG"
        else
            echo "ERROR: GG process is not running: $process_name as of $(date)" >> "$ERROR_LOG"
            status="ERROR"
        fi
    done
}

scan_for_process

# Output the final status
echo "status=$status"

# Exit with appropriate code
if [ "$status" = "OK" ]; then
    exit 0
else
    exit 1
fi
