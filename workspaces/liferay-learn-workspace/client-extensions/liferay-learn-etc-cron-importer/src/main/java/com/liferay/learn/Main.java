/**
 * SPDX-FileCopyrightText: (c) 2000 Liferay, Inc. https://liferay.com
 * SPDX-License-Identifier: LGPL-2.1-or-later OR LicenseRef-Liferay-DXP-EULA-2.0.0-2023-06
 */

package com.liferay.learn;

import java.nio.file.Files;
import java.nio.file.Paths;

/**
 * @author Francesco Acciaro
 */
public class Main {

	public static void main(String[] args) {
		if (!Files.exists(Paths.get("/tmp/liferay_jar_runner_set_up_ok"))) {
			System.err.println(
				"liferay-learn-etc-cron-importer: the setup script did not " +
					"complete, failing the run");

			System.exit(1);
		}

		System.out.println(
			"liferay-learn-etc-cron-importer: setup completed, import not " +
				"yet implemented (F1a)");
	}

}