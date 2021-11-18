#!/bin/bash

# 1rtos/container-api.sh
#  -a library of shell functions to standardize our 1rtos-container interfaces
#
# Usage:
#   a.) Source this file ahead of ahead of any automation calls and call functions directly
#   b.) Call this script with the function name + parameters, eg:
#	container-api.sh 1rtos-ci <workspace> <batch> ....

# 1rtos-ci <workspace> <batch> <parallel> <option>
# ------------------------------------------------
# * standard method for ci/qemu twister with skipList support, both container & repo defined.
#	<workspace> ($1) = path to workspace in container
#	<batch>	    ($2) = which batch number am I
#	<parallel>  ($3) = total number of parallel jobs
#	<extra>     ($4) = optional twister parameter to pass, typically used for "--integration"
1rtos-ci() {
	cd "$1/zephyrproject"
	if [ ! -d .west ]; then
		west init -l zephyr
	fi
	west update

	export ZEPHYR_BASE="$1/zephyrproject/zephyr"
	cd "$1/zephyrproject/zephyr"

	# store all testcases
	scripts/twister -M -x=USE_CCACHE=0 -N --inline-logs -v --save-tests testcases "$4"
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
	scripts/twister -B "$2/$3" -M --load-tests testcases -x=USE_CCACHE=0 -N --inline-logs -v --retry-failed 3 --retry-interval 60 "$4"
}
export -f 1rtos-ci

# process internal method calls

if [ "$1" == "1rtos-ci" ]; then
	1rtos-ci "$2" "$3" "$4" "$5"
fi
