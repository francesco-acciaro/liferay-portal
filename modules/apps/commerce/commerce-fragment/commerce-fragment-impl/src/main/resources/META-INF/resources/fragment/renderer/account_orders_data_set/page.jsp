<%--
/**
 * SPDX-FileCopyrightText: (c) 2025 Liferay, Inc. https://liferay.com
 * SPDX-License-Identifier: LGPL-2.1-or-later OR LicenseRef-Liferay-DXP-EULA-2.0.0-2023-06
 */
--%>

<%@ include file="/fragment/renderer/account_orders_data_set/init.jsp" %>

<frontend-data-set:headless-display
	additionalProps="<%= additionalProps %>"
	apiURL="<%= apiURL %>"
	fdsActionDropdownItems="<%= fdsActionDropdownItems %>"
	id="<%= CommerceFragmentFDSNames.PENDING_ACCOUNT_ORDERS %>"
	itemsPerPage="<%= pageSize %>"
	propsTransformer="{PendingAccountOrdersFDSPropsTransformer} from commerce-fragment-impl"
	showPagination="<%= showPagination %>"
	style="<%= displayStyle %>"
/>

<c:if test="<%= hideActionsColumn %>">
	<aui:style type="text/css">
		.lfr-layout-structure-item-com-liferay-commerce-fragment-internal-renderer-pendingaccountordersdatasetfragmentrenderer table th:last-of-type,
		.lfr-layout-structure-item-com-liferay-commerce-fragment-internal-renderer-pendingaccountordersdatasetfragmentrenderer table td:last-of-type {
			display: none;
		}
	</aui:style>
</c:if>