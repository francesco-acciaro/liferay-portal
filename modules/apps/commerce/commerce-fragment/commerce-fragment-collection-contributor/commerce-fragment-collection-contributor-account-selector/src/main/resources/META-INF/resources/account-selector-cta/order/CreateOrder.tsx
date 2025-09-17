/**
 * SPDX-FileCopyrightText: (c) 2025 Liferay, Inc. https://liferay.com
 * SPDX-License-Identifier: LGPL-2.1-or-later OR LicenseRef-Liferay-DXP-EULA-2.0.0-2023-06
 */

//@ts-ignore
import {createCommerceCart} from 'commerce-frontend-js';

import ClayButton from "@clayui/button";
import React from 'react';

interface  CreateOrderProps {
    commerceChannelId: number;
    addCommerceOrderURL: string;
    currencyCode: string;
    currentCommerceAccount: {
        id: number | string;
        logoURL: string;
        name: string;
    };
    hasAddCommerceOrderPermission: boolean;
}

const CreateOrder = ({
    commerceChannelId,
    addCommerceOrderURL: orderDetailURL,
    currencyCode,
    currentCommerceAccount,
    hasAddCommerceOrderPermission
}: CreateOrderProps) => {
    return (
        <ClayButton
            block
            disabled={!hasAddCommerceOrderPermission}
            onClick={(event) => {
                event.preventDefault();

                createCommerceCart({
                    accountId: currentCommerceAccount.id,
                    commerceChannelId,
                    currencyCode,
                    orderDetailURL
                });
            }}
        >
            {Liferay.Language.get('create-new-order')}
        </ClayButton>
    );
};

export default CreateOrder