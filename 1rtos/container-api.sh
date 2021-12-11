#!/bin/bash

# 1rtos/container-api.sh
#  - standardized CI/QA functions via our 1rtos-test container ( sdk-docker-intel )
#
# Usage:
#   Call this script with the function name + parameters, eg:
#	$ container-api.sh 1rtos-ci <workspace> <batch> ....

# 1rtos-ci workspace batch# parallel# <option-str>
# ------------------------------------------------
# * standard method for ci/qemu twister with skipList support, both container & repo defined.
#	<workspace> ($2) = path to workspace in container
#	<batch#>    ($3) = which batch number am I
#	<parallel#> ($4) = total number of parallel jobs
#	<option-str>($5) = optional twister parameter to pass, typically used for "--integration"
1rtos-ci() {
	cd "$2/zephyrproject"
	if [ ! -d .west ]; then
		west init -l zephyr
	fi
	west update

	export ZEPHYR_BASE="$2/zephyrproject/zephyr"
	cd "$ZEPHYR_BASE"
	
	# set twister cmdline, injecting $5/option-str
	TWISTER_CMD="scripts/twister -M -x=USE_CCACHE=0 -N --inline-logs -v $5" 

	# store all testcases
	$TWISTER_CMD --save-tests testcases
	cp testcases testcases.0

	# apply twisterSkipList if exists in container
	if [ -f /opt/1rtos/twisterSkipList ]; then
		. ./opt/1rtos/twisterSkipList
		for tc in "${TWISTER_SKIP_LIST[@]}"; do
			sed -i "\\#$tc#d" testcases
		done
	fi

	# apply twisterSkipList if exists in repo
	if [ -f .github/workflows/twisterSkipList ]; then
		. .github/workflows/twisterSkipList
		for tc in "${TWISTER_SKIP_LIST[@]}"; do
			sed -i "\\#$tc#d" testcases
		done
	fi

	# run twister with our standard options + injected batch/parallel & extra params
	$TWISTER_CMD -B $3/$4 --load-tests testcases --retry-failed 3 --retry-interval 60
}

echo "oneRTOS container API invoked as: $@"

# process internal method calls
if [ "$1" == "1rtos-ci" ]; then
	1rtos-ci "${@}"
fi
