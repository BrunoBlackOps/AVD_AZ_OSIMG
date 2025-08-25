import os
import sys

import requests

GITLAB_URL = os.getenv("GITLAB_URL", "https://admingitlab.prod.ibkr-int.com")
GITLAB_TOKEN = os.getenv("GITLAB_TOKEN")
GITLAB_PROJECT_ID = os.getenv("CI_PROJECT_ID")
GITLAB_MR_IID = os.getenv("merge_request_iid") # Provided by Webhook template
REQUIRED_APPROVALS = int(os.getenv("REQUIRED_APPROVALS", "2"))

GITLAB_MR_TARGET_BRANCH = os.getenv("CI_MERGE_REQUEST_TARGET_BRANCH_NAME")
if GITLAB_MR_TARGET_BRANCH is None:
    GITLAB_MR_TARGET_BRANCH = os.getenv("target_branch", "none") # target_branch defined in Webhook payload

auth_header = {'PRIVATE-TOKEN': GITLAB_TOKEN}

def get_project_members(s):
    try:
        response = s.get(f"{GITLAB_URL}/api/v4/projects/{GITLAB_PROJECT_ID}/members/all")
        response.raise_for_status()

        data = response.json()

        if data:
            maintainers = [obj['username'] for obj in data if obj['access_level'] >= 40]
            return maintainers
        print("WARNING: No project maintainers found.")
        return []
    except requests.exceptions.HTTPError:
        print(f"API error: {response.status_code} - URL: {response.url} - {response.text}")
        return []
    except requests.exceptions.RequestException as err:
        print(f"API error: {err}")
        return []

def stage_merge_request(s):
    approvers = get_project_members(s)

    try:
        response_author = s.get(f"{GITLAB_URL}/api/v4/projects/{GITLAB_PROJECT_ID}/merge_requests/{GITLAB_MR_IID}")
        author = response_author.json()['author']['username']

        response = s.get(f"{GITLAB_URL}/api/v4/projects/{GITLAB_PROJECT_ID}/merge_requests/{GITLAB_MR_IID}/approvals")
        response.raise_for_status()

        data = response.json()

        # Remove author as an approver when merging to master
        if GITLAB_MR_TARGET_BRANCH == "master":
            approved = [obj['user']['username'] for obj in data['approved_by'] if obj['user']['username'] in approvers and obj['user']['username'] != author]

            if len(approved) >= REQUIRED_APPROVALS:
                print(f"Merge request {GITLAB_MR_IID} approved by: {*approved,}.")
                add_mr_note(s, approved)
                merge_approved_mr(s, GITLAB_MR_IID)
            else:
                print("Required approvals not met.")
            sys.exit(0)
        else:
            approved = [obj['user']['username'] for obj in data['approved_by'] ]

            if len(approved) > 0:
                print(f"Merge request {GITLAB_MR_IID} approved by: {*approved,}.")
                add_mr_note(s, approved)
                merge_approved_mr(s, GITLAB_MR_IID)
            else:
                print("Required approvals not met.")
            sys.exit(0)

    except requests.exceptions.HTTPError:
        print(f"MR Request error: {response.status_code} - URL: {response.url} - {response.text}")
        sys.exit(1)
    except requests.exceptions.RequestException as err:
        print(f"MR Request error :{err}")
        sys.exit(1)
    

def merge_approved_mr(s, mr):

    try:
        response = s.put(f"{GITLAB_URL}/api/v4/projects/{GITLAB_PROJECT_ID}/merge_requests/{mr}/merge",
            params={'should_remove_source_branch': True, 'squash': True})

        response.raise_for_status()
        data = response.json()
    except requests.exceptions.HTTPError:
        print(f"Error: could not merge MR {mr}: {response.status_code}")
    except requests.exceptions.RequestException as err:
        print(f"Error: could not merge MR {mr}: {response.status_code} {err}")

    if data['state'] == "merged":
        print(f"Merged MR {data['iid']}.")

def add_mr_note(s, approvers):
    note = f"Merge request approved by: {*approvers,}"

    try:
        response = s.post(f"{GITLAB_URL}/api/v4/projects/{GITLAB_PROJECT_ID}/merge_requests/{GITLAB_MR_IID}/notes?body={note}")
        response.raise_for_status()
    except requests.exceptions.HTTPError:
        pass
    except requests.exceptions.RequestException:
        pass

def main():

    with requests.Session() as s:
        s.headers.update(auth_header)
        stage_merge_request(s)


if __name__ == '__main__':
    main()

