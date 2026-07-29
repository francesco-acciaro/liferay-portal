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

	if [ "${LIFERAY_LEARN_ETC_CRON_PARTIAL:-}" = "true" ]
	then
		echo "[cron-importer] Partial mode: rsync without --delete."

		delete_flag=""
	fi

	rsync --include="*.zip" --include="*/" --exclude="*" --inplace --prune-empty-dirs --recursive --whole-file "${LIFERAY_LEARN_ETC_CRON_GIT_REPOSITORY_DIR}/site/" /public_html

	rsync ${delete_flag} --inplace --prune-empty-dirs --recursive --whole-file "${LIFERAY_LEARN_ETC_CRON_GIT_REPOSITORY_DIR}/site/examples" /public_html

	copy_tree_sharded "${LIFERAY_LEARN_ETC_CRON_GIT_REPOSITORY_DIR}/site/images" /public_html/images "${delete_flag}"

	if [ -z "${_SKIP_REFERENCE_COPY}" ]
	then
		copy_tree_sharded "${LIFERAY_LEARN_ETC_CRON_GIT_REPOSITORY_DIR}/site/reference" /public_html/reference "${delete_flag}"

		if [ -n "${_REFERENCE_FINGERPRINT}" ]
		then
			echo "${_REFERENCE_FINGERPRINT}" > /public_html/.learn-importer-reference-marker

			echo "[cron-importer] Reference marker updated."
		fi
	fi
}

function copy_tree_sharded {
	local source_dir="${1}" dest_dir="${2}" delete_flag="${3}"

	local work_dir

	work_dir=$(mktemp -d)

	(cd "${source_dir}" && find . -type f) > "${work_dir}/files"

	if [ ! -s "${work_dir}/files" ]
	then
		echo "[cron-importer] Nothing to copy from ${source_dir}."

		return 0
	fi

	split -n l/16 "${work_dir}/files" "${work_dir}/chunk-"

	local pids=()

	local chunk

	for chunk in "${work_dir}"/chunk-*
	do
		rsync --files-from="${chunk}" --inplace --whole-file "${source_dir}/" "${dest_dir}/" &

		pids+=("${!}")
	done

	local pid

	for pid in "${pids[@]}"
	do
		wait "${pid}"
	done

	if [ -n "${delete_flag}" ]
	then
		rsync --delete --existing --ignore-existing --prune-empty-dirs --recursive "${source_dir}/" "${dest_dir}/"
	fi

	rm -fr "${work_dir}"
}

function check_reference_cache {
	_REFERENCE_FINGERPRINT=""
	_SKIP_REFERENCE_COPY=""

	if [ "${LIFERAY_LEARN_ETC_CRON_PARTIAL:-}" = "true" ]
	then
		return 0
	fi

	local common_file="${LIFERAY_LEARN_ETC_CRON_GIT_REPOSITORY_DIR}/_common.sh"

	local doc_file_name release

	doc_file_name=$(sed -n "s/^readonly LIFERAY_LEARN_DXP_DOC_FILE_NAME=//p" "${common_file}")
	release=$(sed -n "s/^readonly LIFERAY_LEARN_DXP_RELEASE_TOKEN_VALUE=//p" "${common_file}")

	if [ -z "${doc_file_name}" ] || [ -z "${release}" ]
	then
		echo "[cron-importer] Reference cache: release tokens not found in _common.sh, forcing a full refresh."

		return 0
	fi

	local total_size

	total_size=$(curl -fsL -H "Range: bytes=0-0" -D- -o /dev/null "https://releases-cdn.liferay.com/dxp/${release}/${doc_file_name}" | tr -d "\r" | grep -i "^content-range:" | tail -1 | sed "s|.*/||")

	if [ -z "${total_size}" ]
	then
		echo "[cron-importer] Reference cache: no fingerprint from the CDN, forcing a full refresh."

		return 0
	fi

	_REFERENCE_FINGERPRINT="${doc_file_name}|${total_size}"

	if [ "${LIFERAY_LEARN_ETC_CRON_FORCE_REFERENCE:-}" = "true" ]
	then
		echo "[cron-importer] Reference cache: forced refresh requested, ignoring the marker."

		return 0
	fi

	if [ -f /public_html/.learn-importer-reference-marker ] && [ "$(cat /public_html/.learn-importer-reference-marker)" = "${_REFERENCE_FINGERPRINT}" ]
	then
		echo "[cron-importer] Reference cache HIT (${_REFERENCE_FINGERPRINT}): skipping javadoc download, extraction and copy."

		_SKIP_REFERENCE_COPY="true"

		export LIFERAY_LEARN_ETC_CRON_SKIP_REFERENCE_DOCS="true"
	else
		echo "[cron-importer] Reference cache MISS (${_REFERENCE_FINGERPRINT}): full javadoc refresh."
	fi
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

	check_reference_cache

	generate_docs

	copy_resources

	if [ "${LIFERAY_LEARN_ETC_CRON_PARTIAL:-}" != "true" ]
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