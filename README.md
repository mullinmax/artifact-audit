# Artifact Audit Toolkit

A small but mighty toolkit that wraps a battle-tested Bash script to audit the
GitHub Actions artifacts that belong to you (personal and organization
repositories alike). It shows you how much storage each repository is using and
lets you prune large or stale artifacts interactively so you can keep your GALP
repository—and every other project—lean.

## Features

- Enumerates personal repositories, organizations, or only the repositories you
  explicitly target.
- Summaries storage usage per repository and overall usage across all
  accessible repositories.
- Interactive review loop with context so you can confidently delete artifacts.
- Release-aware safety checks that skip artifacts tied to the most recent
  release tags.
- Test suite that keeps the core helpers reliable.

## Requirements

| Tool | Why it is needed |
| --- | --- |
| [GitHub CLI (`gh`)](https://cli.github.com/) | Authenticated access to repositories and artifact APIs. |
| [`jq`](https://stedolan.github.io/jq/) | JSON parsing for GitHub API responses. |
| POSIX `awk` | Lightweight floating-point arithmetic for size calculations. |
| `bash` 4+ | Associative arrays and process substitution are used throughout the script. |

## Quick start

1. Clone this repository and move into it:
   ```bash
   git clone https://github.com/your-org/artifact-audit.git
   cd artifact-audit
   ```
2. Authenticate the GitHub CLI if you have not already:
   ```bash
   gh auth login
   ```
3. (Optional) Run the test suite to ensure your environment can execute the
   helpers:
   ```bash
   bash tests/test_artifact_audit.sh
   ```
4. Audit **only** your GALP repository:
   ```bash
   ./artifact_audit.sh --repo your-org/GALP
   ```
5. Audit everything you have access to (personal and org repositories):
   ```bash
   ./artifact_audit.sh
   ```

During the review step you will be shown artifact metadata and prompted to
confirm deletions. The script automatically skips artifacts that appear to be
part of the latest release to help avoid accidental data loss.

## Usage reference

```bash
./artifact_audit.sh [options]
```

| Option | Description |
| --- | --- |
| `--repo <owner/name>` | Limit the audit to one repository. You can repeat this flag for multiple repositories (perfect for the GALP repo). |
| `--skip-personal` | Skip personal repositories and only evaluate organization repositories. |
| `--skip-orgs` | Skip organizations and only evaluate personal repositories. |
| `-h`, `--help` | Print usage details. |

## Repository structure

```
.
├── artifact_audit.sh         # The main script (functions are sourceable for testing)
├── tests/
│   └── test_artifact_audit.sh
└── README.md
```

Feel free to extend the repository with GitHub Actions workflows, cron jobs, or
Dockerfiles if you want to automate audits on a schedule.
