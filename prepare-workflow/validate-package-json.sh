#!/bin/sh

#######################################################################
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License v2.0 which
# accompanies this distribution, and is available at
# https://www.eclipse.org/legal/epl-v20.html
#
# SPDX-License-Identifier: EPL-2.0
#
# Copyright Contributors to the Zowe Project.
#######################################################################

BASE_DIR=$(pwd)

# consider must have been released for a week
safe_release_date=$(TZ=GMT date -v-7d +'%Y-%m-%dT%H:%M:%S.000Z')
echo "Safe release date is before ${safe_release_date}"
echo

package_jsons=$(find . -name package.json)
while read -r package; do
  package=$(echo "${package}" | xargs)
  if [ -z "${package}" ]; then
    continue
  fi

  echo "======================================================================="
  echo ">>>>>>>> ${package}"
  package_dir=$(dirname "${package}")
  cd "${BASE_DIR}" && cd "${package_dir}"

  echo "----------------------------------------------------"
  echo "Validate static dependency versions:"
  categories="dependencies devDependencies optionalDependencies"
  for category in ${categories}; do
    echo "- ${category}"
    dependencies=$(cat package.json | jq -r ".${category} | to_entries[] | .key + \" \" + .value")
    dependencies_rc=$?
    if [ -n "${dependencies}" -a "${dependencies}" != "null" -a "${dependencies_rc}" = "0" ]; then
      while read -r dependency; do
        package=$(echo "${dependency}" | awk '{print $1;}')
        version=$(echo "${dependency}" | awk '{print $2;}')
        echo "  * ${package}@${version}"
        version_first_char=$(echo "${version}" | cut -c 1-1)
        if [ "${version_first_char}" = "^" -o "${version_first_char}" = "~" ]; then
          >&2 echo "Error: ${package}@${version} is not imported with static version."
          exit 1
        fi
        time=$(npm view "${package}@${version}" time --json 2>/dev/null | jq -r ".\"${version}\"")
        time_rc=$?
        echo "    - ${time}"
        if [ -z "${time}" -o "${time}" = "null" -o "${time_rc}" != "0" ]; then
          >&2 echo "Error: cannot find release date of ${package}@${version}"
          exit 1
        fi
        if [[ "${time}" > "${safe_release_date}" ]]; then
          >&2 echo "Error: ${package}@${version} is released at ${time}, which is not considered safe."
          exit 1
        fi
      done <<EOFD
$(echo "${dependencies}")
EOFD
    fi
  done
  echo "All passed!"
  echo

  done <<EOFP
$(echo "${package_jsons}")
EOFP

exit 0