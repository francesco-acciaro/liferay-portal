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

	rsync --include="*.zip" --include="*/" --exclude="*" --prune-empty-dirs --recursive "${LIFERAY_LEARN_ETC_CRON_GIT_REPOSITORY_DIR}/site/" /public_html

	rsync --delete --prune-empty-dirs --recursive "${LIFERAY_LEARN_ETC_CRON_GIT_REPOSITORY_DIR}/site/examples" /public_html

	rsync --delete --prune-empty-dirs --recursive "${LIFERAY_LEARN_ETC_CRON_GIT_REPOSITORY_DIR}/site/images" /public_html

	rsync --delete --prune-empty-dirs --recursive "${LIFERAY_LEARN_ETC_CRON_GIT_REPOSITORY_DIR}/site/reference" /public_html
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

	echo "[cron-importer] Setup completed, handing over to the importer."
}

main "${@}"