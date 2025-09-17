/**
 * SPDX-FileCopyrightText: (c) 2025 Liferay, Inc. https://liferay.com
 * SPDX-License-Identifier: LGPL-2.1-or-later OR LicenseRef-Liferay-DXP-EULA-2.0.0-2023-06
 */

//@ts-ignore
import {commerceEvents} from 'commerce-frontend-js';

import ClayButton from '@clayui/button';
import React from 'react';
import AccountCreationModal from "./AccountCreationModal";
import {useModal} from "@clayui/modal";
import {selectAccount} from "./utils";

interface CreateAccountProps {
    accountEntryAllowedTypes: string[];
    commerceChannelId: number;
    currentAccountURL: string;
    refreshPageOnAccountSelected: boolean;
}

export interface OnAccountChangeParams {
    account: any;
    doCheckout: boolean;
}

const CreateAccount = ({
    accountEntryAllowedTypes,
    commerceChannelId,
    currentAccountURL,
    refreshPageOnAccountSelected}: CreateAccountProps) => {

    const {observer, open, onOpenChange} = useModal();

    const onAccountChange = ({account, doCheckout = false}: OnAccountChangeParams) => {
        selectAccount(account.id, currentAccountURL)
            .then(() => {
                if (refreshPageOnAccountSelected) {
                    window.location.reload();
                }
                else {
                    Liferay.fire(commerceEvents.CURRENT_ACCOUNT_UPDATED, {id: account.id});
                }
            })
            // .catch(showErrorNotification);
            .catch(() => {})
    };

    return (
        <>
            <ClayButton onClick={() => onOpenChange(true)}>
                {Liferay.Language.get('create-new-account')}
            </ClayButton>

            {open && (
                <AccountCreationModal
                    accountTypes={accountEntryAllowedTypes}
                    closeModal={() => onOpenChange(false)}
                    commerceChannelId={commerceChannelId}
                    onAccountChange={onAccountChange}
                    observer={observer}
                />
            )}
        </>
    );
};

export default CreateAccount