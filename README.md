# 🚀 Lite Release

**Lite Release** is an all-in-one GitHub Action designed to automate the tedious parts of software releasing. It handles version bumping, selective file updates (Release vs. Snapshot), Git tagging, and GitHub Release creation—all in a single execution.

---

## ✨ Features

* **Smart Bumping:** Supports `patch`, `minor`, and `major` versioning.
* **Dual-Phase Updates:** Separate file patterns for **Release** (e.g., updating README and Gradle) and **Snapshot** (e.g., updating only Gradle).
* **Version Tracking:** Uses a simple `version.json` file to keep track of release and snapshot versions.
* **Release Templating:** Supports custom Markdown templates with `{VERSION}` placeholders for your release notes.
* **Fully Customizable:** Custom commit messages and release titles using patterns.
* **GitHub CLI Integration:** Uses the native `gh` tool for reliable release creation.

## 🛠️ Setup

### 1. Version File

Create a file at `.github/release/version.json` (or any path you prefer) with the following structure:

```json
{
  "versionRelease": "1.0.0",
  "versionSnapshot": "1.1.0-SNAPSHOT"
}

```

for `versionRelease` use the latest stable version, and for `versionSnapshot` use the next version with `-SNAPSHOT` suffix.

### 2. Permissions

Ensure you use a **Personal Access Token (PAT)** if you want the commits pushed by this action to trigger other workflows (like your CI/CD build or publishing to Maven Central).

### 3. Workflow

Create a workflow file (e.g., `.github/workflows/release.yml`):

```yaml
name: Release
on:
  workflow_dispatch:
    inputs:
      bump:
        description: 'Version Bump'
        type: choice
        options: [patch, minor, major]
        default: 'patch'

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
          token: ${{ secrets.PAT }} # github token or PAT

      - name: Run Lite Release
        uses: rollczi/lite-release@v1
        with:
          # GitHub token or PAT (required)
          token: ${{ secrets.PAT }}
          # version bump type (passed from workflow input) (not required but recommended)
          bump_type: ${{ github.event.inputs.bump }} # default: patch

          # Release commit - here we update all files including README (optional)
          commit_release: 'chore(release): release version {VERSION}'
          commit_release_update_files: 'README.md, **/*.gradle.kts, **/pom.xml, src/main/resources/plugin.yml'
          
          # Snapshot commit - here we update only build files for snapshot (optional)
          commit_snapshot: 'chore(dev): bump snapshot to {VERSION}'
          commit_snapshot_update_files: '**/*.gradle.kts, **/pom.xml'

          # Git config (optional)
          git_user_name: 'LiteRelease Bot'
          git_user_email: 'bot@litecommands.io'

          # GitHub Release (optional)
          github_release_title: '🚀 LiteCommands v{VERSION} - New Features!'
          github_release_template: '.github/release/template.md'
          
          # Path to the version file (optional)
          version_file: '.github/release/version.json'

```

## ⚙️ Configuration

### Inputs

| Input                          | Description                                       | Default                                        |
|--------------------------------|---------------------------------------------------|------------------------------------------------|
| `token`                        | **Required**. GitHub PAT or `GITHUB_TOKEN`.       | N/A                                            |
| `bump_type`                    | Type of version bump (`patch`, `minor`, `major`). | `patch`                                        |
| `commit_release`               | Message for the release commit.                   | `Release {VERSION}`                            |
| `commit_release_update_files`  | Comma-separated globs to update during Release.   | `**/*.gradle.kts, **/pom.xml, README.md`       |
| `commit_snapshot`              | Message for the snapshot bump commit.             | `Snapshot {VERSION}`                           |
| `commit_snapshot_update_files` | Comma-separated globs to update for Snapshot.     | `**/*.gradle.kts, **/pom.xml`                  |
| `git_user_name`                | Name used for Git commits.                        | `github-actions[bot]`                          |
| `git_user_email`               | Email used for Git commits.                       | `github-actions[bot]@users.noreply.github.com` |
| `github_release_title`         | Pattern for the GitHub Release title.             | `Release v{VERSION}`                           |
| `github_release_template`      | Optional path to a `.md` template file.           | `""`                                           |
| `version_file`                 | Path to your version JSON file.                   | `.github/release/version.json`                 |

## 📝 Release Notes Template

If you provide a `github_release_template`, you can use the `{VERSION}` placeholder. The action will also automatically append a list of commits (generated by GitHub) to your template.

**Example `.github/release/template.md`:**

```markdown
# LiteCommands {VERSION} 🚀

Thank you for using LiteCommands!

## 📦 Installation
`implementation("org.example:litecommands:{VERSION}")`
```

## 💡 How it works

1. **Release Phase:**
* Reads `version.json`.
* Calculates the new version based on `bump_type`.
* Replaces the **old release** and **old snapshot** version strings with the **new release** version in all files matching `commit_release_update_files`.
* Commits changes and creates a Git tag.

2. **GitHub Release:**
* Creates a formal GitHub Release using your title pattern and template.

3. **Snapshot Phase:**
* Calculates the next snapshot version (always +1 patch).
* Replaces the **new release** version with the **next snapshot** version, but **only** in files matching `commit_snapshot_update_files`.
* Commits and pushes back to the branch.