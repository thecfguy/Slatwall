/*

    Slatwall - An e-commerce plugin for Mura CMS
    Copyright (C) 2011 ten24, LLC

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
    
    Linking this library statically or dynamically with other modules is
    making a combined work based on this library.  Thus, the terms and
    conditions of the GNU General Public License cover the whole
    combination.
 
    As a special exception, the copyright holders of this library give you
    permission to link this library with independent modules to produce an
    executable, regardless of the license terms of these independent
    modules, and to copy and distribute the resulting executable under
    terms of your choice, provided that you also meet, for each linked
    independent module, the terms and conditions of the license of that
    module.  An independent module is a module which is not derived from
    or based on this library.  If you modify this library, you may extend
    this exception to your version of the library, but you are not
    obligated to do so.  If you do not wish to do so, delete this
    exception statement from your version.

Notes:

*/
component accessors="true" output="false" extends="BaseObject" {

	public any function init() {
		return this;
	}
	
	public any function getCurrentProduct() {
		if(!getService("requestCacheService").keyExists("currentProduct")) {
			if(getService("requestCacheService").keyExists("currentProductID")) {
				getService("requestCacheService").setValue("currentProduct", getService("productService").getProduct(getService("requestCacheService").getValue("currentProductID")));
			} else {
				getService("requestCacheService").setValue("currentProduct", getService("productService").newProduct());	
			}
		}
		return getService("requestCacheService").getValue("currentProduct");
	}
	
	public any function getCurrentSession() {
		return getService("sessionService").getCurrent();
	}
	
	public any function getCurrentAccount() {
		if(!isNull(getCurrentSession().getAccount())) {
			return getCurrentSession().getAccount();
		} else {
			return getService("AccountService").newAccount();	
		}
	}
	
	public any function getCurrentCart() {
		if(!isNull(getCurrentSession().getOrder())) {
			return getCurrentSession().getOrder();
		} else {
			return getService("OrderService").newOrder();	
		}
	}
	
	private any function getProductList(string contentID) {
		if(!structKeyExists(arguments,"contentID")) {
			return getCurrentProductList();
		} else if (arguments.contentID == "" || arguments.contentID == "00000000000000000000000000000000001") {
			if(!getService("requestCacheService").keyExists("allProductList")) {
				var data = {};
				data["F:activeFlag"] = 1;
				data["F:publishedFlag"] = 1;
				if(structKeyExists(request, "context")) {
					structAppend(data, request.context);
				} else {
					structAppend(data, form);
					structAppend(data, url);
				}
				var currentURL = $.createHREF(filename=$.content('filename'));
				if(len(CGI.QUERY_STRING)) {
					currentURL &= "?" & CGI.QUERY_STRING;
				}
				getService("requestCacheService").setValue("allProductList", getService("productService").getProductSmartList(data=data, currentURL=currentURL));
			}
			return getService("requestCacheService").getValue("allProductList");
		} else {
			if(!getService("requestCacheService").keyExists("contentProductList#arguments.contentID#")) {
				var content = $.getBean("content").loadBy(contentID=arguments.contentID, siteID=$.event('siteID'));
				var data = {};
				data["F:activeFlag"] = 1;
				data["F:publishedFlag"] = 1;
				if(content.getExtendedAttribute("showSubPageProducts") eq "") {
					data.showSubPageProducts = 0;
				} else {
					data.showSubPageProducts = content.getExtendedAttribute("showSubPageProducts");	
				}
				var currentURL = $.createHREF(filename=content.getFileName());
				if(len(CGI.QUERY_STRING)) {
					currentURL &= "?" & CGI.QUERY_STRING;
				}
				getService("requestCacheService").setValue("contentProductList#arguments.contentID#", getService("productService").getProductContentSmartList(contentID=arguments.contentID, data=data, currentURL=currentURL));
			}
			return getService("requestCacheService").getValue("contentProductList#arguments.contentID#");
		}
	}
	
	private any function getCurrentProductList() {
		if(!getService("requestCacheService").keyExists("currentProductList")) {
			var data = {};
			data["F:activeFlag"] = 1;
			data["F:publishedFlag"] = 1;
			if(structKeyExists(request, "context")) {
				structAppend(data, request.context);
			} else {
				structAppend(data, form);
				structAppend(data, url);
			}
			if($.content("showSubPageProducts") eq "") {
				data.showSubPageProducts = 0;
			} else {
				data.showSubPageProducts = $.content("showSubPageProducts");	
			}
			if($.event("categoryID") != "") {
				data["F:productCategories_categoryID"] = $.event("categoryID");
			}
			var currentURL = $.createHREF(filename=$.content('filename'));
			if(len(CGI.QUERY_STRING)) {
				currentURL &= "?" & CGI.QUERY_STRING;
			}
			getService("requestCacheService").setValue("currentProductList", getService("productService").getProductContentSmartList(contentID=$.content("contentID"), data=data, currentURL=currentURL));
		}
		return getService("requestCacheService").getValue("currentProductList");
	}
	
	public any function account(string property, string value) {
		if(isDefined("arguments.property") && isDefined("arguments.value")) {
			return evaluate("getCurrentAccount().set#arguments.property#(#arguments.value#)");
		} else if (isDefined("arguments.property")) {
			return evaluate("getCurrentAccount().get#arguments.property#()");
		} else {
			return getCurrentAccount();	
		}
	}
	
	public any function cart(string property, string value) {
		if(structKeyExists(arguments, "property") && structKeyExists(arguments, "value")) {
			return getCurrentCart().invokeMethod("set#arguments.property#", {1=arguments.value});
		} else if (isDefined("arguments.property")) {
			return getCurrentCart().invokeMethod("get#arguments.property#", {});
		} else {
			return getCurrentCart();	
		}
	}
	
	public any function product(string property, string value) {
		if(isDefined("arguments.property") && isDefined("arguments.value")) {
			return evaluate("getCurrentProduct().set#arguments.property#(#arguments.value#)");
		} else if (isDefined("arguments.property")) {
			return evaluate("getCurrentProduct().get#arguments.property#()");
		} else {
			return getCurrentProduct();
		}
	}
	
	public any function productList(string property, string value, string contentID) {
		if(structKeyExists(arguments, "property") && structKeyExists(arguments, "value")) {
			if(structKeyExists(arguments, "contentID")) {
				return evaluate("getProductList(arguments.contentID).set#arguments.property#(#arguments.value#)");	
			} else {
				return evaluate("getCurrentProductList().set#arguments.property#(#arguments.value#)");
			}
		} else if (structKeyExists(arguments, "property")) {
			if(structKeyExists(arguments, "contentID")) {
				return evaluate("getProductList(arguments.contentID).get#arguments.property#()");
			} else {
				return evaluate("getCurrentProductList().get#arguments.property#()");
			}
		} else {
			if(structKeyExists(arguments, "contentID")) {
				return getProductList(arguments.contentID);
			} else {
				return getCurrentProductList();
			}
		}
	}
	
	public any function session(string property, string value) {
		if(structKeyExists(arguments, "property") && structKeyExists(arguments, "value")) {
			return evaluate("getCurrentSession().set#arguments.property#(#arguments.value#)");
		} else if (structKeyExists(arguments, "property")) {
			return evaluate("getCurrentSession().get#arguments.property#()");
		} else {
			return getCurrentSession();	
		}
	}
	
	public any function sessionFacade(string property, string value) {
		if(structKeyExists(arguments, "property") && structKeyExists(arguments, "value")) {
			return getService("sessionService").setValue(arguments.property, arguments.value);
		} else if (structKeyExists(arguments, "property")) {
			return getService("sessionService").getValue(arguments.property);
		} else {
			return getService("sessionService");	
		}
	}
	
	public void function addVTScript( ) {
		var script = getValidateThis().getValidationScript( argumentcollection = arguments );
		
		if(!getService("requestCacheService").keyExists("vtScripts")) {
			getService("requestCacheService").setValue("vtScripts", []);	
		}
		
		arrayAppend(getService("requestCacheService").getValue("vtScripts"), script);
	}
	
	public string function renderVTScript() {
		var scripts = [];
		var outputScript = "";
		
		if(getService("requestCacheService").keyExists("vtScripts")) {
			scripts = getService("requestCacheService").getValue("vtScripts");
		}
		
		outputScript &= '<script type="text/javascript">';
		outputScript &= 'jQuery(document).ready(function(){';
		 
		for(var i=1; i<=arrayLen(scripts); i++) {
			outputScript &= replace(replace(replace(replace(scripts[i],'<script type="text/javascript">',''),'</script>',''),'/*<![CDATA[*/','','all'),'/*]]>*/','','all');
		}
		
		outputScript &= '});</script>';
		
		return outputScript;
	}
	
	
	
	// Public methods that expose some of the base objects private methods
	public string function rbKey(required string key, string local) {
		return super.rbKey(argumentCollection=arguments);
	}
	
	public string function setting(required string settingName) {
		return super.setting(argumentcollection=arguments);
	}
	
	public string function getAPIKey(required string resource, required string verb) {
		return super.getAPIKey(argumentcollection=arguments);
	}
	
	public string function getSlatwallRootPath() {
		return super.getSlatwallRootPath(argumentcollection=arguments);
	}
	
	public string function getSlatwallRootDirectory() {
		return super.getSlatwallRootDirectory(argumentcollection=arguments);
	}
	
	public any function getCFStatic() {
		return super.getCFStatic(argumentcollection=arguments);
	}
	
	public any function getValidateThis() {
		return super.getValidateThis(argumentcollection=arguments);
	}
	// END: Public methods that expose some of the base objects private methods
}