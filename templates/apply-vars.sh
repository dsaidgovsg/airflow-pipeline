#!/usr/bin/env bash
if [[ ! -v TERA ]] && ! command -v tera >/dev/null; then
    printf "Run \"cargo install tera-cli\" to install tera first.\nLinux users may download from https://github.com/guangie88/tera-cli/releases instead."
    return 1
elif [[ ! -v TERA ]]; then
    TERA="$(command -v tera)"
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

${TERA} -f "${DIR}/ci.yml.tmpl" --yaml "${DIR}/vars.yml" > "${DIR}/../.github/workflows/ci.yml" && \
printf "Successfully applied template into ci.yml!\n"
