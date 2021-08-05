#!/bin/bash
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
#

timestampRegex="[[:digit:]]{4}-[[:digit:]]{2}-[[:digit:]]{2}-[[:digit:]]{2}-[[:digit:]]{2}"

# IF YOU ARE MODIFYING THIS THEN THE FILE MATCHING IS PROBABLY WRONG, MAKE SURE openjdk-api, v2.js IS UPDATED TOO
#      OpenJDK 8U_             -jdk        x64_           Linux_         hotspot_         2018-06-15-10-10                .tar.gz
#      OpenJDK 11_             -jdk        x64_           Linux_         hotspot_         11_28                           .tar.gz
regex="OpenJDK([[:digit:]]+)U?(-jre|-jdk)_([[:alnum:]\-]+)_([[:alnum:]]+)_([[:alnum:]]+).*\.(tar\.gz|zip|pkg|msi)";
regexArchivesOnly="${regex}$";

if [ -z "${TAG}" ]; then
    echo "Must have a tag set"
    exit 1
fi

if [ "$RELEASE" != "true" ] && [ -z "${TIMESTAMP}" ]; then
    echo "Nightly must have a TIMESTAMP set"
    exit 1
fi

if [ -z "${GITHUB_SERVER}" ]; then
   server=""
else
   server="--server \"${GITHUB_SERVER}\""
fi

if [ -z "${GITHUB_ORG}" ]; then
   org=""
else
   org="--org \"${GITHUB_ORG}\""
fi

# Rename to ensure a consistent timestamp across release
for file in OpenJDK*
do
  echo "Processing $file";

  if [[ $file =~ $regexArchivesOnly ]];
  then
    newName=$(echo "${file}" | sed -r "s/${timestampRegex}/$TIMESTAMP/")

    if [ "${file}" != "${newName}" ]; then
      # Rename archive and checksum file with new timestamp
      echo "Renaming ${file} to ${newName}"
      mv "${file}" "${newName}"
      mv "${file}.sha256.txt" "${newName}.sha256.txt"
      mv "${file}.json" "${newName}.json"
    fi

    # Fix checksum file name
    strippedFileName=$(echo "${newName}" | sed -r "s/.+\\///g")
    sed -i -r "s/^([0-9a-fA-F ]+).*/\1${strippedFileName}/g" "${newName}.sha256.txt"

    FILE_VERSION=${BASH_REMATCH[1]};
    FILE_TYPE=${BASH_REMATCH[2]};
    FILE_ARCH=${BASH_REMATCH[3]};
    FILE_OS=${BASH_REMATCH[4]};
    FILE_VARIANT=${BASH_REMATCH[5]};
    FILE_TS_OR_VERSION=${BASH_REMATCH[6]};
    FILE_EXTENSION=${BASH_REMATCH[8]};

    echo "version:${FILE_VERSION} type: ${FILE_TYPE} arch:${FILE_ARCH} os:${FILE_OS} variant:${FILE_VARIANT} timestamp or version:${FILE_TS_OR_VERSION} timestamp:${TIMESTAMP} extension:${FILE_EXTENSION}";
  fi
done

files=`ls $PWD/OpenJDK*{.tar.gz,.sha256.txt,.zip,.pkg,.msi,.json} | sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/ /g'`

echo "Release: $RELEASE"

RELEASE_OPTION=""
if [ "$RELEASE" == "true" ]; then
  description="Official Release of $TAG"
  RELEASE_OPTION="--release"
else
  TAG="${TAG}-beta"
  description="Nightly Build of $TAG"
fi

if [ "$DRY_RUN" == "false" ]; then
    cd adopt-github-release
    chmod +x gradlew
    GRADLE_USER_HOME=./gradle-cache ./gradlew --no-daemon run --args="--version \"${VERSION}\" --tag \"${TAG}\" --description \"${description}\" ${server} ${org} $RELEASE_OPTION $files"
fi
