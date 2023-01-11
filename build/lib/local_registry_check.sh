#!/usr/bin/env bash
# Copyright Amazon.com Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e
set -o pipefail
set -x

function registry_ready() {
  for i in {1..24}
  do
    if ! curl http://$IMAGE_REPO/ > /dev/null 2>&1;
    then
      echo "Local registry at ${IMAGE_REPO} is not running. Retrying."
      sleep 5
    else
      exit 0
    fi
  done
  echo "Local registry at ${IMAGE_REPO} is not available"
  exit 1
}

registry_ready