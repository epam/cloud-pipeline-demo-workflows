#!/usr/bin/env bash

# set -x

# Copyright 2017-2025 EPAM Systems, Inc. (https://www.epam.com/)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# Comment

LOCAL_NXF_PIPELINE="$SCRIPTS_DIR/src/al-docking-1.0.0"
export NXF_PIPELINE="$SHARED_WORK_FOLDER/pipeline"

CP_SLEEP_AFTER_FAIL="${CP_SLEEP_AFTER_FAIL:-false}"
CP_SLEEP_AFTER_FAIL_HOURS="${CP_SLEEP_AFTER_FAIL_HOURS:-24}"

NXF_PIPELINE_TASK="al.docking"

# rm -rf "$NXF_PIPELINE"

# rm -rf $ANALYSIS_DIR       && mkdir -p $ANALYSIS_DIR
# rm -rf $SHARED_WORK_FOLDER && mkdir -p $SHARED_WORK_FOLDER

cp -r "$LOCAL_NXF_PIPELINE" "$NXF_PIPELINE"
cp "$SCRIPTS_DIR/src/*.config" "$SHARED_WORK_FOLDER/"
cd "$SHARED_WORK_FOLDER"

NXF_COMMAND="nextflow run $NXF_PIPELINE \
	--receptor_sheet $receptor_sheet \
	--cache_path /common/cache \
	--outdir $ANALYSIS_DIR \
	-params-file $params_file \
	-c $custom_config_path \
	-resume -ansi-log false"

# `custom_config_path` - contains `compound_db` and related settings
# `params_file`        - any pipeline parameters

# 	-c fix-retry-wo-exitcode.config \

if [[ -n "$cache_zip" ]]; then
  NXF_COMMAND="$NXF_COMMAND --cache_zip $cache_zip"
fi

if [[ -n "$NXF_DUMP_CHANNELS" ]]; then
  NXF_COMMAND="$NXF_COMMAND -dump-channels"
fi

pipe_exec "$NXF_COMMAND" "$NXF_PIPELINE_TASK"
if [[ "$?" -ne 0 ]]; then
	pipe_log_fail "[ERROR] There are some troubles while executing pipeline" "$NXF_PIPELINE_TASK"
	if [ "$CP_SLEEP_AFTER_FAIL" == "true" ]; then
		pipe_log_info "[INFO] Suspend the pipeline execution for ${CP_SLEEP_AFTER_FAIL_HOURS} hours to find out the failure cause." "$NXF_PIPELINE_TASK"
	    sleep ${CP_SLEEP_AFTER_FAIL_HOURS}h
	fi
	exit 1
fi
pipe_log_success "Finished al.docking" "$NXF_PIPELINE_TASK"
