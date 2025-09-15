/**
 * SPDX-FileCopyrightText: (c) 2000 Liferay, Inc. https://liferay.com
 * SPDX-License-Identifier: LGPL-2.1-or-later OR LicenseRef-Liferay-DXP-EULA-2.0.0-2023-06
 */

package com.liferay.commerce.fragment.renderer.account.selector.action.internal;

import com.liferay.account.model.AccountEntry;
import com.liferay.commerce.configuration.CommerceOrderCheckoutConfiguration;
import com.liferay.commerce.configuration.CommerceOrderFieldsConfiguration;
import com.liferay.commerce.constants.CommerceConstants;
import com.liferay.commerce.constants.CommerceOrderActionKeys;
import com.liferay.commerce.constants.CommerceOrderConstants;
import com.liferay.commerce.constants.CommerceWebKeys;
import com.liferay.commerce.context.CommerceContext;
import com.liferay.commerce.currency.model.CommerceCurrency;
import com.liferay.commerce.frontend.taglib.internal.model.CurrentCommerceAccountModel;
import com.liferay.commerce.frontend.taglib.internal.servlet.ServletContextUtil;
import com.liferay.commerce.order.CommerceOrderHttpHelper;
import com.liferay.commerce.service.CommerceOrderLocalService;
import com.liferay.fragment.model.FragmentEntryLink;
import com.liferay.fragment.renderer.FragmentRenderer;
import com.liferay.fragment.renderer.FragmentRendererContext;
import com.liferay.fragment.util.configuration.FragmentEntryConfigurationParser;
import com.liferay.frontend.taglib.react.servlet.taglib.ComponentTag;
import com.liferay.petra.string.StringBundler;
import com.liferay.petra.string.StringPool;
import com.liferay.portal.configuration.module.configuration.ConfigurationProvider;
import com.liferay.portal.kernel.exception.PortalException;
import com.liferay.portal.kernel.json.JSONException;
import com.liferay.portal.kernel.json.JSONFactory;
import com.liferay.portal.kernel.json.JSONObject;
import com.liferay.portal.kernel.language.Language;
import com.liferay.portal.kernel.log.Log;
import com.liferay.portal.kernel.log.LogFactoryUtil;
import com.liferay.portal.kernel.security.permission.resource.PortletResourcePermission;
import com.liferay.portal.kernel.settings.GroupServiceSettingsLocator;
import com.liferay.portal.kernel.theme.ThemeDisplay;
import com.liferay.portal.kernel.util.GetterUtil;
import com.liferay.portal.kernel.util.HashMapBuilder;
import com.liferay.portal.kernel.util.PortalUtil;
import com.liferay.portal.kernel.util.ResourceBundleUtil;
import com.liferay.portal.kernel.util.StringUtil;
import com.liferay.portal.kernel.util.WebKeys;
import com.liferay.portal.kernel.webserver.WebServerServletTokenUtil;
import com.liferay.taglib.servlet.PageContextFactoryUtil;
import jakarta.servlet.ServletContext;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.osgi.service.component.annotations.Component;
import org.osgi.service.component.annotations.Reference;

import java.io.IOException;
import java.util.Locale;
import java.util.Map;
import java.util.ResourceBundle;

@Component(service = FragmentRenderer.class)
public class AccountSelectorActionFragmentRenderer implements FragmentRenderer {

	@Override
	public String getCollectionKey() {
		return "account-selector-action";
	}

	@Override
	public JSONObject getConfigurationJSONObject(
		FragmentRendererContext fragmentRendererContext) {

		ResourceBundle resourceBundle = ResourceBundleUtil.getBundle(
			"content.Language", getClass());

		try {
			JSONObject jsonObject = _jsonFactory.createJSONObject(
				StringUtil.read(
					getClass(),
					"fragment/renderer/configuration.json"));

			return _fragmentEntryConfigurationParser.translateConfiguration(
				jsonObject, resourceBundle);
		}
		catch (JSONException jsonException) {
			if (_log.isDebugEnabled()) {
				_log.debug(jsonException);
			}

			return null;
		}
	}

	@Override
	public String getIcon() {
		return "button";
	}

	@Override
	public String getLabel(Locale locale) {
		return _language.get(locale, "account-selector-action");
	}

	@Override
	public void render(
		FragmentRendererContext fragmentRendererContext,
		HttpServletRequest httpServletRequest,
		HttpServletResponse httpServletResponse)
		throws IOException {

		CommerceContext commerceContext =
			(CommerceContext) httpServletRequest.getAttribute(
				CommerceWebKeys.COMMERCE_CONTEXT);

		if (commerceContext == null) {
			return;
		}

		try {
			FragmentEntryLink fragmentEntryLink =
			fragmentRendererContext.getFragmentEntryLink();
			String actionType = _getConfigurationValue(
			fragmentRendererContext, fragmentEntryLink, "actionType");

			if(!_moduleImportNames.containsKey(actionType)) {
				if(_log.isDebugEnabled()) {
					_log.error("No moduleImportName found for actionType: " + actionType);
				}

				return;
			}

			ComponentTag componentTag = new ComponentTag();

			String moduleImportName = _moduleImportNames.get(actionType);
			componentTag.setModule("{ "+ moduleImportName + " } from commerce-fragment-renderer-account-selector-action-impl");
			componentTag.setPageContext(
			PageContextFactoryUtil.create(
			httpServletRequest, httpServletResponse));
			componentTag.setServletContext(_servletContext);
			CommerceCurrency commerceCurrency =
				commerceContext.getCommerceCurrency();
			_accountEntry = commerceContext.getAccountEntry();
			_themeDisplay = (ThemeDisplay)httpServletRequest.getAttribute(
				WebKeys.THEME_DISPLAY);
			_commerceOrderLocalService =
				ServletContextUtil.getCommerceOrderLocalService();
			_commerceOrderPortletResourcePermission =
				ServletContextUtil.getCommerceOrderPortletResourcePermission();
			_configurationProvider = ServletContextUtil.getConfigurationProvider();
			_commerceChannelGroupId =
				commerceContext.getCommerceChannelGroupId();
			_commerceChannelId = commerceContext.getCommerceChannelId();

			String thumbnailUrl;

			if (_accountEntry.getLogoId() == 0) {
				thumbnailUrl =
					_themeDisplay.getPathImage() +
					"/organization_logo?img_id=0";
			}
			else {
				thumbnailUrl = StringBundler.concat(
					_themeDisplay.getPathImage(), "/organization_logo?img_id=",
					_accountEntry.getLogoId(), "&t=",
					WebServerServletTokenUtil.getToken(
						_accountEntry.getLogoId()));
			}

			CurrentCommerceAccountModel currentCommerceAccountModel =
				new CurrentCommerceAccountModel(
					_accountEntry.getAccountEntryId(), thumbnailUrl,
					_accountEntry.getName());

			componentTag.setProps(
				HashMapBuilder.<String, Object>put(
				"accountEntryAllowedTypes",
				commerceContext.getAccountEntryAllowedTypes()
			).put(
				"addCommerceOrderURL", _commerceOrderHttpHelper.getCommerceCartBaseURL(httpServletRequest)
			).put(
				"commerceChannelId", commerceContext.getCommerceChannelId()
			).put(
				"currentAccountURL", PortalUtil.getPortalURL(httpServletRequest) +
									 PortalUtil.getPathContext() +
									 "/o/commerce-ui/set-current-account"
			).put(
				"currentCommerceAccount", currentCommerceAccountModel
			).put(
				"currencyCode", commerceCurrency.getCode()
			).put(
				"hasAddCommerceOrderPermission", _hasAddCommerceOrderPermission()
			).put(
				"refreshPageOnAccountSelected", true
			).build());

			componentTag.doStartTag();

			componentTag.doEndTag();
		}
		catch (Exception exception) {
			throw new IOException(exception);
		}
	}

	private String _getConfigurationValue(
		FragmentRendererContext fragmentRendererContext,
		FragmentEntryLink fragmentEntryLink, String fieldName) {

		return GetterUtil.getString(
			_fragmentEntryConfigurationParser.getFieldValue(
				getConfigurationJSONObject(fragmentRendererContext),
				fragmentEntryLink.getEditableValuesJSONObject(),
				fragmentRendererContext.getLocale(), fieldName));
	}

	private boolean _hasAddCommerceOrderPermission() {
		if ((_accountEntry == null) || (_themeDisplay == null)) {
			return false;
		}

		try {
			CommerceOrderFieldsConfiguration commerceOrderFieldsConfiguration =
				_configurationProvider.getConfiguration(
					CommerceOrderFieldsConfiguration.class,
					new GroupServiceSettingsLocator(
						_commerceChannelGroupId,
						CommerceConstants.SERVICE_NAME_COMMERCE_ORDER_FIELDS));

			int commerceOrdersCount =
				(int)_commerceOrderLocalService.getCommerceOrdersCount(
					_accountEntry.getCompanyId(), _commerceChannelGroupId,
					new long[] {_accountEntry.getAccountEntryId()},
					StringPool.BLANK,
					new int[] {CommerceOrderConstants.ORDER_STATUS_OPEN},
					false);

			if ((commerceOrderFieldsConfiguration.accountCartMaxAllowed() >
				 0) &&
				(commerceOrdersCount >=
				 commerceOrderFieldsConfiguration.accountCartMaxAllowed())) {

				return false;
			}

			CommerceOrderCheckoutConfiguration
				commerceOrderCheckoutConfiguration =
				_configurationProvider.getConfiguration(
					CommerceOrderCheckoutConfiguration.class,
					new GroupServiceSettingsLocator(
						_commerceChannelGroupId,
						CommerceConstants.SERVICE_NAME_COMMERCE_ORDER));

			if (_accountEntry.isGuestAccount() &&
				commerceOrderCheckoutConfiguration.guestCheckoutEnabled()) {

				return true;
			}
		}
		catch (PortalException portalException) {
			_log.error(portalException);
		}

		return _commerceOrderPortletResourcePermission.contains(
			_themeDisplay.getPermissionChecker(),
			_accountEntry.getAccountEntryGroupId(),
			CommerceOrderActionKeys.ADD_COMMERCE_ORDER);
	}

	private static final Log _log = LogFactoryUtil.getLog(
		AccountSelectorActionFragmentRenderer.class);

	private AccountEntry _accountEntry;
	private long _commerceChannelGroupId;
	private long _commerceChannelId;
	private PortletResourcePermission _commerceOrderPortletResourcePermission;
	private CommerceOrderLocalService _commerceOrderLocalService;
	private ConfigurationProvider _configurationProvider;
	private final Map<String, String> _moduleImportNames = Map.of("createAccount", "CreateAccount", "createOrder", "CreateOrder");
	private ThemeDisplay _themeDisplay;

	@Reference
	private CommerceOrderHttpHelper _commerceOrderHttpHelper;

	@Reference
	private FragmentEntryConfigurationParser _fragmentEntryConfigurationParser;

	@Reference
	private JSONFactory _jsonFactory;

	@Reference
	private Language _language;

	@Reference(target = "(osgi.web.symbolicname=com.liferay.commerce.fragment.renderer.account.selector.action.impl)")
	private ServletContext _servletContext;
}