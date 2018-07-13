#!/bin/bash
set -eo pipefail

defaultSuite='bionic'
declare -A suites=(
	[5.5]='trusty'
	[10.0]='xenial'
)
defaultXtrabackup='mariadb-backup'
declare -A xtrabackups=(
	[5.5]='percona-xtrabackup'
	[10.0]='percona-xtrabackup'
)

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

travisEnv=
for version in "${versions[@]}"; do
	suite="${suites[$version]:-$defaultSuite}"
	fullVersion="$(
		curl -fsSL "http://ftp.osuosl.org/pub/mariadb/repo/$version/ubuntu/dists/$suite/main/binary-amd64/Packages" \
			| tac|tac \
			| awk -F ': ' '$1 == "Package" { pkg = $2; next } $1 == "Version" && pkg == "mariadb-server" { print $2; exit }'
	)"
	if [ -z "$fullVersion" ]; then
		echo >&2 "warning: cannot find $version in $suite"
		continue
	fi

	backup="${xtrabackups[$version]:-$defaultXtrabackup}"
	# 10.1 and 10.2 have mariadb major version in the package name
	if [ "$backup" == 'mariadb-backup' ] && [[ "$version" < 10.3 ]]; then
		backup="$backup-$version"
	fi
	(
		set -x
		cp docker-entrypoint.sh "$version/"
		sed \
			-e 's!%%MARIADB_VERSION%%!'"$fullVersion"'!g' \
			-e 's!%%MARIADB_MAJOR%%!'"$version"'!g' \
			-e 's!%%SUITE%%!'"$suite"'!g' \
			-e 's!%%XTRABACKUP%%!'"$backup"'!g' \
			Dockerfile.template \
			> "$version/Dockerfile"
	)
	
	travisEnv='\n  - VERSION='"$version$travisEnv"
done

travis="$(awk -v 'RS=\n\n' '$1 == "env:" { $0 = "env:'"$travisEnv"'" } { printf "%s%s", $0, RS }' .travis.yml)"
echo "$travis" > .travis.yml
