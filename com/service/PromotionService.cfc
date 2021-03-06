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
component extends="Slatwall.com.service.BaseService" persistent="false" accessors="true" output="false" {
	
	public any function savePromotion(required any promotion, struct data={}) {
		
		// Turn off sub-property populating because it will be managed manually in this method.
		arguments.data.populateSubProperties = false;
		
		// Populate the promotion
		arguments.promotion.populate(arguments.data);
		
		// Populate the promotion codes
		if(structKeyExists(arguments.data, "promotionCodes") && isArray(arguments.data.promotionCodes)) {
			for(var i=1; i<=arrayLen(arguments.data.promotionCodes); i++) {
				// Get the promotion code
				var promotionCode = this.getPromotionCode(arguments.data.promotionCodes[i].promotionCodeID, true);
				
				// Populate it with the new data
				promotionCode.populate(arguments.data.promotionCodes[i]);
				
				// Set it in promotion
				arguments.promotion.addPromotionCode(promotionCode);
				
				// Add to the populated sub properties
				if(!arrayFind(arguments.promotion.getPopulatedSubProperties(), "promotionCodes")) {
					arrayAppend(arguments.promotion.getPopulatedSubProperties(), "promotionCodes");
				}
			}
		}
		
		// Check to see if we are going to update or editing any rewards (TPC) 
		if(structKeyExists(arguments.data, "savePromotionRewardProduct") && arguments.data.savePromotionRewardProduct) {
			// Get product reward, and return a new one if not found
			var prProduct = this.getPromotionRewardProduct(arguments.data.promotionRewards[1].promotionRewardID, true);
			
			// Populate that product reward
			prProduct.populate(arguments.data.promotionRewards[1]);
			
			// Validate the product reward
			prProduct.validate();
			
			// Add the promotion reward to the promotion
			arguments.promotion.addPromotionReward(prProduct);
			
			// add to the sub items populated so that we can validate on parent
			arrayAppend(arguments.promotion.getPopulatedSubProperties(), "promotionRewards");
			
		} else if (structKeyExists(arguments.data, "savePromotionRewardShipping") && arguments.data.savePromotionRewardShipping) {
			// Get shipping reward, and return a new one if not found
			var prShipping = this.getPromotionRewardShipping(arguments.data.promotionRewards[1].promotionRewardID, true);
			
			// Get shipping reward, and return a new one if not found
			prShipping.populate(arguments.data.promotionRewards[1]);
			
			// Validate the shipping reward
			prShipping.validate();
			
			// Add the promotion reward to the promotion
			arguments.promotion.addPromotionReward(prShipping);
			
			// add to the sub items populated so that the parent validate method checks for errors in the children
			arrayAppend(arguments.promotion.getPopulatedSubProperties(), "promotionRewards");
		}

		// Validate the promotion, this will also check any sub-entities that got populated 
		arguments.promotion.validate();
		
		// If the object passed validation then call save in the DAO, otherwise set the errors flag
		if(!arguments.promotion.hasErrors()) {
			arguments.promotion = getDAO().save(target=arguments.promotion);
		} else {
			getService("requestCacheService").setValue("ormHasErrors", true);
        }
		
		return arguments.promotion;
	}
		
	// ----------------- START: Apply Promotion Logic ------------------------- 
	public void function updateOrderAmountsWithPromotions(required any order) {
		
		if(arguments.order.getOrderType().getSystemCode() == "otSalesOrder") {
			// Get All of the active current promotions
			var promotions = getDAO().getAllActivePromotions();
	
			// Clear all previously applied promotions for order items
			for(var oi=1; oi<=arrayLen(arguments.order.getOrderItems()); oi++) {
				for(var pa=1; pa<=arrayLen(arguments.order.getOrderItems()[oi].getAppliedPromotions()); pa++) {
					arguments.order.getOrderItems()[oi].getAppliedPromotions()[pa].removeOrderItem();
				}
			}
			// TODO: Clear all previously applied promotions from fulfillments
			// TODO: Clear all previously applied promotions from order
								
			
			// Loop over each promotion to determine if it applies to this order
			for(var p=1; p<=arrayLen(promotions); p++) {
				var promotion = promotions[p];
				
				var qc = getPromotionQualificationCount(promotion=promotion, order=arguments.order);
				
				if(qc >= 0) {
					for(var r=1; r<=arrayLen(promotions[p].getPromotionRewards()); r++) {
						var reward = promotions[p].getPromotionRewards()[r];
						
						// If this reward is a product then run this logic
						if(reward.getRewardType() eq "product") {
							// Loop over each of the items to see if the promotion gets applied
							for(var i=1; i<=arrayLen(arguments.order.getOrderItems()); i++) {
								
								// Get The order Item
								var orderItem = arguments.order.getOrderItems()[i];
								
								if(
									( !arrayLen( reward.getProductTypes() ) || reward.hasProductType( orderItem.getSku().getProduct().getProductType() ) )
									&&
									( !arrayLen( reward.getProducts() ) || reward.hasProduct( orderItem.getSku().getProduct() ) )
									&&
									( !arrayLen( reward.getSkus() ) || reward.hasSku( orderItem.getSku() ) )
									&&
									( !arrayLen( reward.getBrands() ) || reward.hasBrand( orderItem.getSku().getProduct().getBrand() ) )
									&&
									( !arrayLen( reward.getOptions() ) || reward.hasAnyOption( orderItem.getSku().getOptions() ) )
								) {
									// Now that we know that this orderItem gets this reward we can figure out the amount
									var discountAmount = getDiscountAmount(reward, orderItem.getExtendedPrice());
									
									var addNew = false;
									
									// If there aren't any promotions applied to this order item yet, then we can add this one
									if(!arrayLen(orderItem.getAppliedPromotions())) {
										addNew = true;
									// If one has already been set then we just need to check if this new discount amount is greater
									} else if ( orderItem.getAppliedPromotions()[1].getDiscountAmount() < discountAmount ) {
										// If the promotion is the same, then we just update the amount
										if(orderItem.getAppliedPromotions()[1].getPromotion().getPromotionID() == promotions[p].getPromotionID()) {
											orderItem.getAppliedPromotions()[1].setDiscountAmount(discountAmount);
										// If the promotion is a different then remove the original and set addNew to true
										} else {
											orderItem.getAppliedPromotions()[1].removeOrderItem();
											addNew = true;
										}
									}
									
									// Add the new appliedPromotion
									if(addNew) {
										var newAppliedPromotion = this.newOrderItemAppliedPromotion();
										newAppliedPromotion.setPromotion(promotions[p]);
										newAppliedPromotion.setOrderItem(orderItem);
										newAppliedPromotion.setDiscountAmount(discountAmount);
									}
								}
							}
							
						} else if(reward.getRewardType() eq "fulfillment") {
							// TODO: Allow for fulfillment Rewards
						} else if(reward.getRewardType() eq "order") {
							// TODO: Allow for order Rewards
						}
						
					}
				}
			}
		}
		
	}
	
	public numeric function calculateSkuSalePrice(required any sku) {
		// TODO: Impliment me!
		return arguments.sku.getPrice();
	}
	
	public date function calculateSkuSalePriceExpirationDateTime(required any sku) {
		// TODO: Impliment me!
		return now()+30;
	}
	
	private numeric function getDiscountAmount(required any reward, required any originalAmount) {
		var discountAmount = 0;
		
		if(!isNull(reward.getItemAmount())) {
			discountAmount = arguments.originalAmount - reward.getItemAmount();
		} else if( !isNull(reward.getItemAmountOff()) ) {
			discountAmount = reward.getItemAmountOff();
		} else if( !isNull(reward.getItemPercentageOff()) ) {
			discountAmount = arguments.originalAmount * (reward.getItemPercentageOff()/100);
		}
		
		if(reward.getItemAmountOff() > arguments.originalAmount) {
			discountAmount = arguments.originalAmount;
		}
		
		return numberFormat(discountAmount, "0.00");
	}
	
	private numeric function getPromotionQualificationCount(required any promotion, required any order) {
		var qc = -1;
		var codesOK = false;
		var accountOK = false;
		
		
		// Verify Promo Code Requirements 
		if(!arrayLen(arguments.promotion.getPromotionCodes())) {
			codesOK = true;
		} else {
			// Loop over each promotion code in the order
			for(var i=1; i<=arrayLen(arguments.order.getPromotionCodes()); i++) {
				
				// Check each promotion code available and see if there is a code that applies
				for(var p=1; p<=arrayLen(arguments.promotion.getPromotionCodes()); p++) {
					
					// Set the promotionCode start and end time into local variables
					var promotionCodeStartDateTime = arguments.promotion.getPromotionCodes()[p].getStartDateTime();
					var promotionCodeEndDateTime = arguments.promotion.getPromotionCodes()[p].getEndDateTime();
					
					// If start and end aren't set, then use the promotions start and end.
					if(isNull(promotionCodeStartDateTime)) {
						promotionCodeStartDateTime = arguments.promotion.getStartDateTime();
					}
					if(isNull(promotionCodeEndDateTime)) {
						promotionCodeEndDateTime = arguments.promotion.getEndDateTime();
					}
					
					// Check if the promotion code meets all of the requirements
					if(arguments.promotion.getPromotionCodes()[p].getPromotionCode() == arguments.order.getPromotionCodes()[i].getPromotionCode() && promotionCodeStartDateTime <= now() && promotionCodeEndDateTime >= now()) {
						codesOK = true;
					}
				}
			}
		}
		
		// TODO: Verify Promo Account Requirements, for now this is just set to true
		accountOK = true;
		
		if(codesOK && accountOK) {
			qc = 0;
		}
		
		return qc;
	}
	
	// ----------------- END: Apply Promotion Logic -------------------------
		 
	/*
	  I needed a place to write down some notes about how applied promotions will be reset, and this is it.
	  Promotions applied on orderItem, fulfillment & order are easy because they can be calculated at the time of the order
	  However we also need to keep a table of promotions applied to products and customers so that on the listing page we can
	  query a discount amount to order by price
	  
	  So now we need a method to reset all of the discount amounts.
	  
	  public void function resetPromotionsAppled(string promotionID, string productTypeID, string productID, string skuID, string accountID) {
	  
	  		// Whichever of the arguments get passed in, we need to get the promotionID's that are effected by that item, and then re-call this method with that promotions ID
	  		
	  		// When this method is called with a promotionID, it will delete everything in the promotionsApplied table that is sku or sku + customer and recalculate the amount
	  }
	  
	*/
		
}
