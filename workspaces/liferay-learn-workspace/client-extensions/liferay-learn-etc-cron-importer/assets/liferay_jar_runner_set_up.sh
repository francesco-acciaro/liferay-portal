#!/bin/bash

set -euo pipefail

function check_generated_site {
	local html_count

	html_count=$(find "${LIFERAY_LEARN_ETC_CRON_GIT_REPOSITORY_DIR}/site" -name "*.html" -newer "${_GENERATION_START_MARKER}" | wc -l)

	if [ "${html_count}" -eq 0 ]
	then
		echo "[cron-importer] ERROR: no fresh HTML generated, refusing to publish stale content"

		exit 1
	fi

	echo "[cron-importer] Generated ${html_count} fresh HTML files."
}

function clone_repository {
	echo "[cron-importer] Phase: clone"

	eval "$(ssh-agent -s)"

	echo -e "-----BEGIN OPENSSH PRIVATE KEY-----\n${LIFERAY_LEARN_ETC_CRON_GITHUB_DEPLOY_KEY}\n-----END OPENSSH PRIVATE KEY-----" | ssh-add -

	export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new -q"

	rm -fr "${LIFERAY_LEARN_ETC_CRON_GIT_REPOSITORY_DIR}"

	git clone --branch "${LIFERAY_LEARN_ETC_CRON_GITHUB_BRANCH:-master}" --depth 1 --single-branch "git@github.com:${LIFERAY_LEARN_ETC_CRON_GITHUB_USER:-liferay}/liferay-learn.git" "${LIFERAY_LEARN_ETC_CRON_GIT_REPOSITORY_DIR}"

	git -C "${LIFERAY_LEARN_ETC_CRON_GIT_REPOSITORY_DIR}" log -1 --pretty="Cloned at commit: %H %aN %s"
}

function copy_resources {
	echo "[cron-importer] Phase: copy resources"

	local delete_flag="--delete"

	if [ -n "${LIFERAY_LEARN_ETC_CRON_PARTIAL:-}" ]
	then
		echo "[cron-importer] Partial mode: rsync without --delete."

		delete_flag=""
	fi

	rsync --include="*.zip" --include="*/" --exclude="*" --prune-empty-dirs --recursive "${LIFERAY_LEARN_ETC_CRON_GIT_REPOSITORY_DIR}/site/" /public_html

	rsync ${delete_flag} --prune-empty-dirs --recursive "${LIFERAY_LEARN_ETC_CRON_GIT_REPOSITORY_DIR}/site/examples" /public_html

	rsync ${delete_flag} --prune-empty-dirs --recursive "${LIFERAY_LEARN_ETC_CRON_GIT_REPOSITORY_DIR}/site/images" /public_html

	rsync ${delete_flag} --prune-empty-dirs --recursive "${LIFERAY_LEARN_ETC_CRON_GIT_REPOSITORY_DIR}/site/reference" /public_html
}

function generate_docs {
	echo "[cron-importer] Phase: generate docs"

	_GENERATION_START_MARKER=$(mktemp)

	pushd "${LIFERAY_LEARN_ETC_CRON_GIT_REPOSITORY_DIR}"

	./generate_docs.sh

	popd

	check_generated_site
}

function main {
	clone_repository

	generate_docs

	copy_resources

	if [ -z "${LIFERAY_LEARN_ETC_CRON_PARTIAL:-}" ]
	then
		write_manifest
	else
		echo "[cron-importer] Partial mode: manifest not written (it only describes full runs)."
	fi

	touch /tmp/liferay_jar_runner_set_up_ok

	echo "[cron-importer] Setup completed, handing over to the importer."
}

function write_manifest {
	echo "[cron-importer] Phase: write manifest"

	local commit

	commit=$(git -C "${LIFERAY_LEARN_ETC_CRON_GIT_REPOSITORY_DIR}" rev-parse HEAD)

	local zips_json

	zips_json=$(cd "${LIFERAY_LEARN_ETC_CRON_GIT_REPOSITORY_DIR}/site" && find . -name "*.zip" -type f | sed "s|^\./||" | sort | awk '{printf "%s\"%s\"", separator, $0; separator = ", "}')

	cat > /public_html/.learn-importer-manifest.json <<EOF
{
	"generatedAt": "$(date --iso-8601=seconds --utc)",
	"managedRoots": ["examples", "images", "reference"],
	"managedZips": [${zips_json}],
	"sourceCommit": "${commit}"
}
EOF

	echo "[cron-importer] Manifest written to /public_html/.learn-importer-manifest.json."
}

main "${@}"