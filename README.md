# github-tag-action

A Github Action to automatically bump and tag master, on merge, with the latest SemVer formatted version.

[![Build Status](https://github.com/Magikon/github-tag-action/workflows/Bump%20version/badge.svg)](https://github.com/Magikon/github-tag-action/workflows/Bump%20version/badge.svg)
[![Stable Version](https://img.shields.io/github/v/tag/Magikon/github-tag-action)](https://img.shields.io/github/v/tag/Magikon/github-tag-action)
[![Latest Release](https://img.shields.io/github/v/release/Magikon/github-tag-action?color=%233D9970)](https://img.shields.io/github/v/release/Magikon/github-tag-action?color=%233D9970)

> Medium Post: [Creating A Github Action to Tag Commits](https://itnext.io/creating-a-github-action-to-tag-commits-2722f1560dec)

[<img src="https://miro.medium.com/max/1200/1*_4Ex1uUhL93a3bHyC-TgPg.png" width="400">](https://itnext.io/creating-a-github-action-to-tag-commits-2722f1560dec)

### Usage

```Dockerfile
name: Bump version
on:
  push:
    branches:
      - master
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
      with:
        fetch-depth: '0'
    - name: Bump version and push tag
      uses: Magikon/github-tag-action@v4.0.5
      id: tag
      env:
        INITIAL_VERSION: 0.0.0
        RELEASE_BRANCHES: development
        TAG_CONTEXT: branch
        PREFIX: dev
        MAJOR: "BREAKING*CHANGE|*#major*"
        MINOR: "*feat*|*#minor*"
        PATCH: "*fix*|*chore*|*docs*|*update*|#patch"
        FORCE: true
```

_NOTE: set the fetch-depth for `actions/checkout@v2` to be sure you retrieve all commits to look for the semver commit message._

#### Options

**Environment Variables**

- **DEFAULT_BUMP** _(optional)_ - Which type of bump to use when none explicitly provided (default: `minor`).
- **WITH_V** _(optional)_ - Tag version with `v` character.
- **RELEASE_BRANCHES** _(optional)_ - Comma separated list of branches (bash reg exp accepted) that will generate the release tags. Other branches and pull-requests generate versions postfixed with the commit hash and do not generate any tag. Examples: `master` or `.*` or `release.*,hotfix.*,master` ...
- **CUSTOM_TAG** _(optional)_ - Set a custom tag, useful when generating tag based on f.ex FROM image in a docker image. **Setting this tag will invalidate any other settings set!**
- **SOURCE** _(optional)_ - Operate on a relative path under $GITHUB_WORKSPACE.
- **DRY_RUN** _(optional)_ - Determine the next version without tagging the branch. The workflow can use the outputs `new_tag` and `tag` in subsequent steps. Possible values are `true` and `false` (default).
- **INITIAL_VERSION** _(optional)_ - Set initial version before bump. Default `0.0.0`.
- **TAG_CONTEXT** _(optional)_ - Set the context of the previous tag. Possible values are `repo` (default) or `branch`.
- **PRERELEASE_SUFFIX** _(optional)_ - Suffix for your prerelease versions, `beta` by default. Note this will only be used if a prerelease branch.
- **FORCE** _(optional)_ - forces to read the tag according to the text from the commits. Possible values are `true` (default) and `false`.
- **MAJOR** _(optional) - Major changes from commits ex. `"BREAKING*CHANGE|*#major*"`
- **MINOR** _(optional) - Minor changes from commits ex. `"*feat*|*#minor*"`
- **PATCH** _(optional) - Patch changes from commits ex. `"*fix*|*chore*|*docs*|*update*"`
- **PREFIX** _(optional) - ex. `dev-v0.2.4`

#### Outputs

- **new_tag** - The value of the newly created tag.
- **tag** - The value of the latest tag after running this action.
- **part** - The part of version which was bumped.
- **oldhash** - Print last tag commit SHA
- **newhash** - Print current tag commit SHA

With oldhash and newhash you can find out if the content of the folder has changed during the last tag and new tag or not.
```- name: Get changed files in apps/auth/src/migrations/ folder
     id: changed-files-auth
     run: |
       test=$(git diff ${{ steps.tag.outputs.oldhash }} ${{ steps.tag.outputs.newhash }} --stat -- apps/auth/src/migrations/ | wc -l)
       (( $test )) && echo "::set-output name=any_changed::true || echo "::set-output name=any_changed::false
       echo "If there are changes in the folder, then the test variable is greater than zero. Current test=$test"

  - name: Run a step if any files have changed in the apps/auth/src/migrations/ folder
    if: ${{ contains(steps.changed-files-auth.outputs.any_changed, 'true') }}
    id: auth-migration-run
      run: |
        ....
```
> **_Note:_** This action creates a [lightweight tag](https://developer.github.com/v3/git/refs/#create-a-reference).

### Bumping

**Manual Bumping:** Any commit message that includes `#major`, `#minor`, `#patch` will trigger the respective version bump. If two or more are present, the highest-ranking one will take precedence.

**Automatic Bumping:** If no `#major`, `#minor` or `#patch` tag is contained in the commit messages, it will bump whichever `DEFAULT_BUMP` is set to (which is `minor` by default). Disable this by setting `DEFAULT_BUMP` to `none`.

> **_Note:_** This action **will not** bump the tag if the `HEAD` commit has already been tagged.

### Workflow

- Add this action to your repo
- Commit some changes
- Either push to master or open a PR
- On push (or merge), the action will:
  - Get latest tag
  - Bump tag with minor version unless any commit message contains `#major` or `#patch`
  - Pushes tag to github
  - If triggered on your repo's default branch (`master` or `main` if unchanged), the bump version will be a release tag.
  - If triggered on any other branch, a prerelease will be generated, depending on the bump, starting with `*-<PRERELEASE_SUFFIX>.1`, `*-<PRERELEASE_SUFFIX>.2`, ...

### Credits

[fsaintjacques/semver-tool](https://github.com/fsaintjacques/semver-tool)
[anothrNick/github-tag-action](https://github.com/anothrNick/github-tag-action)



  > Access JSON structure with HTTP path parameters as keys/indices to the JSON.
