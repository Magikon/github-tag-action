#!/bin/bash

set -o pipefail

# config
default_semvar_bump=${DEFAULT_BUMP:-""}
with_v=${WITH_V:-false}
release_branches=${RELEASE_BRANCHES:-master,main}
custom_tag=${CUSTOM_TAG}
prefix=${PREFIX:-""}
source=${SOURCE:-.}
dryrun=${DRY_RUN:-false}
initial_version=${INITIAL_VERSION:-0.0.0}
tag_context=${TAG_CONTEXT:-repo}
suffix=${PRERELEASE_SUFFIX:-prerelease}
major=${MAJOR:-#major}
minor=${MINOR:-#minor}
patch=${PATCH:-#patch}
force=${FORCE:-false}

cd ${GITHUB_WORKSPACE}/${source}

echo "*** CONFIGURATION ***"
echo -e "\tDEFAULT_BUMP: ${default_semvar_bump}"
echo -e "\tWITH_V: ${with_v}"
echo -e "\tRELEASE_BRANCHES: ${release_branches}"
echo -e "\tCUSTOM_TAG: ${custom_tag}"
echo -e "\tPREFIX: ${prefix}"
echo -e "\tSOURCE: ${source}"
echo -e "\tDRY_RUN: ${dryrun}"
echo -e "\tINITIAL_VERSION: ${initial_version}"
echo -e "\tTAG_CONTEXT: ${tag_context}"
echo -e "\tPRERELEASE_SUFFIX: ${suffix}"
echo -e "\tMAJOR: ${major}"
echo -e "\tMINOR: ${minor}"
echo -e "\tPATCH: ${patch}"
echo -e "\tFORCE: ${force}"


current_branch=$(git rev-parse --abbrev-ref HEAD)

pre_release="true"
IFS=',' read -ra branch <<< "$release_branches"
for b in "${branch[@]}"; do
    echo "Is $b a match for ${current_branch}"
    if [[ "${current_branch}" =~ $b ]]
    then
        pre_release="false"
    fi
done
echo "pre_release = $pre_release"

# fetch tags
git fetch --tags
    
tagFmt="^v?[0-9]+\.[0-9]+\.[0-9]+$" 
preTagFmt="^v?[0-9]+\.[0-9]+\.[0-9]+(-$suffix\.[0-9]+)?$" 

if [ -z "$prefix" ]
then
# get latest tag that looks like a semver (with or without v)
    case "$tag_context" in
        *repo*) 
            taglist="$(git for-each-ref --sort=-v:refname --format '%(refname:lstrip=2)' | grep -E "$tagFmt")"
			[ -z "$taglist" ] || tag="$(semver $taglist | tail -n 1)"
    
            pre_taglist="$(git for-each-ref --sort=-v:refname --format '%(refname:lstrip=2)' | grep -E "$preTagFmt")"
            [ -z "$pre_taglist" ] || pre_tag="$(semver "$pre_taglist" | tail -n 1)"
            ;;
        *branch*) 
            taglist="$(git tag --list --merged HEAD --sort=-v:refname | grep -E "$tagFmt")"
            [ -z "$taglist" ] || tag="$(semver $taglist | tail -n 1)"
    
            pre_taglist="$(git tag --list --merged HEAD --sort=-v:refname | grep -E "$preTagFmt")"
            [ -z "$pre_taglist" ] || pre_tag=$(semver "$pre_taglist" | tail -n 1)
            ;;
        * ) echo "Unrecognised context"; exit 1;;
    esac
else
# get latest tag that looks like a semver (with or without v)
    case "$tag_context" in
        *repo*)
            taglist="$(git for-each-ref --format '%(refname:lstrip=2)' --sort=-v:refname | grep $prefix- | sed -e "s/^$prefix-//" | grep -E "$tagFmt")"
            [ -z "$taglist" ] || tag="$(semver $taglist | tail -n 1)"
            ;;            
        *branch*)         
            taglist="$(git tag --list --merged HEAD --sort=-v:refname $prefix* | sed -e "s/^$prefix-//" | grep -E "$tagFmt")"
            [ -z "$taglist" ] || tag="$(semver $taglist | tail -n 1)"
            ;;
        * ) echo "Unrecognised context"; exit 1;;
    esac
fi

# if there are none, start tags at INITIAL_VERSION which defaults to 0.0.0
if [ -z "$tag" ]
then
    tag="$initial_version"
    if [ -z "$pre_tag" ] && $pre_release
    then
      pre_tag="$initial_version"
    fi
fi

shopt -s extglob;
if $force
then
  IFS=$'\n' read -d '' -a array <<< $(git log --pretty=format:"%s" $current_branch --reverse --no-merges)
  new=$initial_version
  for i in "${array[@]}"
  do 
    case "$i" in
      @($major) ) new=$(semver -i major $tag) ;;
      @($minor) ) new=$(semver -i minor $tag) ;;
      @($patch) ) new=$(semver -i patch $tag) ;;
      * ) [ -z "$default_semvar_bump" ] || new=$(semver -i "${default_semvar_bump}" $tag) ;;
    esac
    tag=$new
  done
  if $with_v
  then
    [ -z $prefix ] && old=$(git tag --list --sort=-version:refname "$prefix-v*" | head -n 1) || old=$(git tag --list --sort=-version:refname "v*" | head -n 1)
  else
    [ -z $prefix ] && old=$(git tag --list --sort=-version:refname "$prefix-*" | head -n 1) || old=$(git tag --list --sort=-version:refname "*" | head -n 1)
  fi
  if [ "$old" == "$new" ]
  then
    echo ::set-output name=new_tag::$tag; echo ::set-output name=tag::$tag; exit 0 
  fi
else
  log=$(git log --pretty=format:"%s" $current_branch --no-merges | head -n 1)
  case "$log" in
    @($major) ) new=$(semver -i major $tag); part="major";;
    @($minor) ) new=$(semver -i minor $tag); part="minor";;
    @($patch) ) new=$(semver -i patch $tag); part="patch";;
    * ) 
        if [ -z "$default_semvar_bump" ]; then
            echo "Default bump was set to none. Skipping..."; echo ::set-output name=new_tag::$tag; echo ::set-output name=tag::$tag; exit 0 
        else 
            new=$(semver -i "${default_semvar_bump}" $tag); part=$default_semvar_bump 
        fi 
        ;;
  esac
fi
shopt -u extglob;


if $pre_release
then
    # Already a prerelease available, bump it
    if [[ "$pre_tag" == *"$new"* ]]; then
        new=$(semver -i prerelease $pre_tag --preid $suffix); part="pre-$part"
    else
        new="$new-$suffix.1"; part="pre-$part"
    fi
fi

echo $part

# prefix with 'v'
if $with_v
then
	new="v$new"
fi

if [ ! -z $custom_tag ]
then
    new="$custom_tag"
fi

if [ ! -z $prefix ]
then
    new="$prefix-$new"
fi

if $pre_release
then
    echo -e "Bumping tag ${pre_tag}. \n\tNew tag ${new}"
else
    echo -e "Bumping tag ${tag}. \n\tNew tag ${new}"
fi

# set outputs
echo ::set-output name=new_tag::$new
echo ::set-output name=part::$part

commit=$(git rev-parse HEAD)

# use dry run to determine the next tag
if $dryrun
then
    echo ::set-output name=tag::$tag
    exit 0
fi 

echo ::set-output name=tag::$new

# create local git tag
git tag $new

# push new tag ref to github
dt=$(date '+%Y-%m-%dT%H:%M:%SZ')
full_name=$GITHUB_REPOSITORY
git_refs_url=$(jq .repository.git_refs_url $GITHUB_EVENT_PATH | tr -d '"' | sed 's/{\/sha}//g')

echo "$dt: **pushing tag $new to repo $full_name"

git_refs_response=$(
curl -s -X POST $git_refs_url \
-H "Authorization: token $GITHUB_TOKEN" \
-d @- << EOF

{
  "ref": "refs/tags/$new",
  "sha": "$commit"
}
EOF
)

git_ref_posted=$( echo "${git_refs_response}" | jq .ref | tr -d '"' )

echo "::debug::${git_refs_response}"
if [ "${git_ref_posted}" = "refs/tags/${new}" ]; then
  exit 0
else
  echo "::error::Tag was not created properly."
  exit 1
fi
