#!/bin/bash

# Suggested by Github actions to be strict
set -e;
set -o pipefail;

################################################################################
# Global Variables (we can't use GITHUB_ prefix)
################################################################################

API_VERSION=v3;
BASE=https://api.github.com;
AUTH_HEADER="Authorization: token ${GITHUB_TOKEN}";
HEADER="Accept: application/vnd.github.${API_VERSION}+json";
HEADER="${HEADER}; application/vnd.github.antiope-preview+json; application/vnd.github.shadow-cat-preview+json";

# URLs
REPO_URL="${BASE}/repos/${GITHUB_REPOSITORY}";
PULLS_URL="${REPO_URL}/pulls";

################################################################################
# Helper Functions
################################################################################

# handle_last_exit_code() { if [[ "$1" != 0 ]]; then exit "$1" fi }

check_credentials() {

    if [[ -z "${GITHUB_TOKEN}" ]]; then
        echo "can not find GITHUB_TOKEN in environment variables";
        exit 1;
    fi
    echo "using GITHUB_TOKEN in environment variables";

}

check_events_json() {

    # path to file that contains the POST response of the event
    # Example: https://github.com/actions/bin/tree/master/debug
    # Value: /github/workflow/event.json

    if [[ ! -f "${GITHUB_EVENT_PATH}" ]]; then
        echo "can not find github events file in GITHUB_EVENT_PATH ${GITHUB_EVENT_PATH}";
        exit 1;
    fi
    echo "using github events file in GITHUB_EVENT_PATH ${GITHUB_EVENT_PATH}";

}

create_pull_request() {

    SOURCE="${1}";  # from this branch
    TARGET="${2}";  # pull request TO this target
    BODY="${3}";    # this is the content of the message
    TITLE="${4}";   # pull request title
    DRAFT="${5}";   # if PRs are draft
    ORG="${6}"; # repo org
    LABEL="${7}"; # label

    # check if the branch already has a pull request open
    RESPONSE=$(curl -sSL -H "${AUTH_HEADER}" -H "${HEADER}" -X GET "${PULLS_URL}?base=${TARGET}&head=${ORG}:${SOURCE}");
    PR=$(echo "${RESPONSE}" | jq --raw-output '.[] | .head.ref');

    echo "response ref: ${PR}";

    if [[ "${PR}" == "${SOURCE}" ]]; then
        # pull request already open
        echo "pull request from SOURCE ${SOURCE} to TARGET ${TARGET} is already open";
    else
        gh pr create --repo ${GITHUB_REPOSITORY} --title "${TITLE}" --body "${BODY}" --base "${TARGET}" --head "${SOURCE}" ${DRAFT} ${LABEL}
    fi
}

main () {
    check_events_json;

    # BRANCH_PREFIX
    if [[ -z "${BRANCH_PREFIX}" ]]; then
        echo "no BRANCH_PREFIX is set";
        BRANCH_PREFIX="";
    else
        echo "using BRANCH_PREFIX $BRANCH_PREFIX";
    fi

    # BASE_BRANCH
    if [[ -z "${BASE_BRANCH}" ]]; then
        echo "no BASE_BRANCH is set";
        BASE_BRANCH=$(jq -r ".repository.default_branch" "$GITHUB_EVENT_PATH");
    fi
    echo "using BASE_BRANCH ${BASE_BRANCH}";

    ORG=$(jq -r ".repository.organization" "$GITHUB_EVENT_PATH");
    echo "using ORG ${ORG}"

    # PULL_REQUEST_DRAFT
    if [[ -z "${PULL_REQUEST_DRAFT}" ]]; then
        echo "no PULL_REQUEST_DRAFT set";
        PULL_REQUEST_DRAFT="";
    elif [ "false" == "${PULL_REQUEST_DRAFT}" ]; then
        PULL_REQUEST_DRAFT="";
    else
        PULL_REQUEST_DRAFT="--draft";
    fi
    echo "using PULL_REQUEST_DRAFT $PULL_REQUEST_DRAFT";

    # PULL_REQUEST_LABEL
    if [[ -z "${PULL_REQUEST_LABEL}" ]]; then
        echo "no PULL_REQUEST_LABEL set";
        PULL_REQUEST_LABEL="";
    else
        PULL_REQUEST_LABEL="--label ${PULL_REQUEST_LABEL}";
    fi
    echo "using PULL_REQUEST_LABEL $PULL_REQUEST_LABEL";


    # get target branch
    HEAD_BRANCH=$(jq --raw-output .ref "${GITHUB_EVENT_PATH}");
    HEAD_BRANCH=$(echo "${HEAD_BRANCH/refs\/heads\//}");

    echo "using HEAD_BRANCH $HEAD_BRANCH";

    if [[ "${HEAD_BRANCH}" == "${BASE_BRANCH}" ]]; then
        echo "HEAD_BRANCH ${HEAD_BRANCH} is BASE_BRANCH ${BASE_BRANCH}";
    else
        if [[ $HEAD_BRANCH == ${BRANCH_PREFIX}* ]]; then
            check_credentials;

            # PULL_REQUEST_BODY
            if [[ -z "${PULL_REQUEST_BODY}" ]]; then
                echo "no PULL_REQUEST_BODY set";
                PULL_REQUEST_BODY="${HEAD_BRANCH}";
            else
                echo "using PULL_REQUEST_BODY ${PULL_REQUEST_BODY}";
            fi

            # PULL_REQUEST_TITLE
            if [[ -z "${PULL_REQUEST_TITLE}" ]]; then
                echo "no PULL_REQUEST_TITLE set";
                PULL_REQUEST_TITLE="${HEAD_BRANCH}";
            fi
            echo "using PULL_REQUEST_TITLE ${PULL_REQUEST_TITLE}";

            create_pull_request "${HEAD_BRANCH}" "${BASE_BRANCH}" "${PULL_REQUEST_BODY}" "${PULL_REQUEST_TITLE}" "${PULL_REQUEST_DRAFT}" "${ORG}" "${PULL_REQUEST_LABEL}";
        fi
    fi
}

echo "==========================================================================";

main;

echo "==========================================================================";
