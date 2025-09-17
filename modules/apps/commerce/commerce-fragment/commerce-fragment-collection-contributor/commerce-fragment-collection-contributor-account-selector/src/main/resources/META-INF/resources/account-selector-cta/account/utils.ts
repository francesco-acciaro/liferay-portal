export function selectAccount(id: any, actionURL: any) {
    const endpointURL = new URL(actionURL, Liferay.ThemeDisplay.getPortalURL());

    endpointURL.searchParams.append(
        'groupId',
        //@ts-ignore
        Liferay.ThemeDisplay.getScopeGroupId()
    );
    endpointURL.searchParams.append('p_auth', Liferay.authToken);

    const body = new FormData();

    body.append('accountId', id);

    return fetch(endpointURL, {body, method: 'POST'});
}