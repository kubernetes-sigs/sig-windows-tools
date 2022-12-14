#!/bin/bash
set -e
set -u
set -o pipefail

## DESCRIPTION:
##
## This script queries all repos in a given github org and adds and issues 
## with label 'sig/windows' to a specified project board.
##
## REREQS:
##
## This script assumes there is a github PAT in the GITHUB_TOKEN env var
## that was created with the following permissions:
##   - repo (all)
##   - read:org
##   - user (all)
##   - read:enterprise
##   - project (all)

GH_ORG=${GH_ORG:-'kubernetes'}
ISSUES_PROJECT_NUMBER=${ISSUES_PROJECT_NUMBER:-'82'}
PRS_PROJECT_NUMBER=${PRS_PROJECT_NUMBER:-'99'}

echo "GH_ORG=${GH_ORG}"

function get_project_id_from_number() {
    project_id="$(gh api graphql -f query='
    query($org: String!, $number: Int!) {
        organization(login: $org) {
            projectV2(number: $number) {
                id
            }
        }
    }' -f org="${GH_ORG}" -F number="$1" --jq '.data.organization.projectV2.id')"
    echo "$project_id"
}

# Get project ID
issues_project_id=$( get_project_id_from_number "$ISSUES_PROJECT_NUMBER" )
echo "project id for issues (number $ISSUES_PROJECT_NUMBER): ${issues_project_id}"
prs_project_id=$( get_project_id_from_number "$PRS_PROJECT_NUMBER" )
echo "project id for prs (number $PRS_PROJECT_NUMBER): ${prs_project_id}"

# Get list of repos in the org
repos_json="$(gh api graphql --paginate -f query='
    query($org: String!, $endCursor: String) {
        viewer {
            organization(login: $org) {
                repositories(first:100, after: $endCursor) {
                    nodes {
                        name
                    }
                    pageInfo {
                        hasNextPage
                        endCursor
                    }
                }
            }
        }
    }' -f org="${GH_ORG}")"

repos="$(jq ".data.viewer.organization.repositories.nodes[].name" <<< "$repos_json" |  tr -d '"' )"

for repo in $repos
do
    echo "Looking for issues in ${GH_ORG}/${repo}"

    # TODO: paginate this query
    issues_json="$(gh api graphql -f query='
        query($org: String!, $repo: String!) {
            repository(owner: $org, name: $repo) {
                issues(last: 100, labels: ["sig/Windows"], states: OPEN) {
                    totalCount
                    nodes {
                        id
                        number
                        title
                    }
                }
            }
        }' -f org="${GH_ORG}" -f repo="${repo}")"

    num_issues=$(jq ".data.repository.issues.nodes | length" <<< "$issues_json")
    echo "  found ${num_issues} in repo"

    if [ "$num_issues" -gt 0 ]; then
        range=$((num_issues - 1))
        for i in $(seq 0 $range)
        do
            issue_id=$(jq ".data.repository.issues.nodes[$i].id" <<< "$issues_json")
            issue_title=$(jq ".data.repository.issues.nodes[$i].title" <<< "$issues_json")
            issue_number=$(jq ".data.repository.issues.nodes[$i].number" <<< "$issues_json")
            echo "    adding ${issue_number} - ${issue_title}"

            gh api graphql -f query='
                mutation($project:ID!, $issue:ID!) {
                    addProjectV2ItemById(input: {projectId: $project, contentId: $issue}) {
                        item {
                            id
                        }
                    }
                }' -f project="${issues_project_id}" -f issue="${issue_id}" --jq .data.addProjectV2ItemById.item.id > /dev/null
        done
    fi

    echo "Looking for PRs in ${GH_ORG}/${repo}"
        # TODO: paginate this query
    prs_json="$(gh api graphql -f query='
        query($org: String!, $repo: String!) {
            repository(owner: $org, name: $repo) {
                pullRequests(last: 100, labels: ["sig/Windows"], states: OPEN) {
                    totalCount
                    nodes {
                        id
                        number
                        title
                    }
                }
            }
        }' -f org="${GH_ORG}" -f repo="${repo}")"

    num_prs=$(jq ".data.repository.pullRequests.nodes | length" <<< "$prs_json")
    echo "  found ${num_prs} in repo"

    if [ "$num_prs" -gt 0 ]; then
        range=$((num_prs - 1))
        for i in $(seq 0 $range)
        do
            pr_id=$(jq ".data.repository.pullRequests.nodes[$i].id" <<< "$prs_json")
            pr_title=$(jq ".data.repository.pullRequests.nodes[$i].title" <<< "$prs_json")
            pr_number=$(jq ".data.repository.pullRequests.nodes[$i].number" <<< "$prs_json")
            echo "    adding ${pr_number} - ${pr_title}"

            gh api graphql -f query='
                mutation($project:ID!, $pr:ID!) {
                    addProjectV2ItemById(input: {projectId: $project, contentId: $pr}) {
                        item {
                            id
                        }
                    }
                }' -f project="${prs_project_id}" -f pr="${pr_id}" --jq .data.addProjectV2ItemById.item.id > /dev/null
        done
    fi
done
