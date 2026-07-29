#!/bin/bash

if [ ! -f /tmp/liferay_jar_runner_main_ok ]
then
	echo "[cron-importer] Job failed: the importer did not complete successfully."

	exit 1
fi

echo "[cron-importer] Job completed successfully."