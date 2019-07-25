#!/usr/bin/env bash
if ! which tera >/dev/null; then
    printf "Run \"cargo install tera-cli\" to install tera first.\nLinux users may download from https://github.com/guangie88/tera-cli/releases instead."
    return 1
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

tera -f "${DIR}/.travis.yml.tmpl" --yaml "${DIR}/vars.yml" > "${DIR}/../.travis.yml" && \
printf "Successfully applied template into .travis.yml!\n"
