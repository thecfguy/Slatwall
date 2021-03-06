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
component displayname="Base Entity" accessors="true" extends="Slatwall.com.utility.BaseObject" {

	property name="persistableErrors" type="array";
	
	// @hint global constructor arguments.  All Extended entities should call super.init() so that this gets called
	public any function init() {
		// Place reference to mura scope in entity
		if(!structKeyExists(request, "muraScope")) {
			request.muraScope = new mura.MuraScope('default');
		}
		variables.$ = request.muraScope;
		
		return super.init();
	}
	
	// @hint Returns the persistableErrors array, if one hasn't been setup yet it returns a new one
	public array function getPersistableErrors() {
		if(!structKeyExists(variables, "persistableErrors")) {
			variables.persistableErrors = [];
		}
		return variables.persistableErrors; 
	}
	
	// @hint this method is defined so that it can be overriden in entities and a different validation context can be applied based on what this entity knows about itself
	public any function getValidationContext(required string context) {
		return arguments.context;
	}
	
	// @hint public method that returns if this entity has persisted to the database yet or not.
	public boolean function isNew() {
		if(getPrimaryIDValue() == "") {
			return true;
		}
		return false;
	}
	
	// @hint public method to determine if this entity can be deleted
	public boolean function isDeletable() {
		
		var results = getValidateThis().validate(theObject=this, context="delete", injectResultIntoBO="false");
		
		if(results.hasErrors()) {
			return false;	
		}
		
		return true;
	}
	
	// hint overriding the addError method to allow for saying that the error doesn't effect persistance
	public void function addError( required string errorName, required string errorMessage, boolean persistableError=false ) {
		if(persistableError) {
			addPersistableError(arguments.errorName);
		}
		super.addError(argumentCollection=arguments);
	}
	
	// @hint this allows you to add error names to the persistableErrors property, later used by the 'isPersistable' method
	public void function addPersistableError(required string errorName) {
		arrayAppend(getPersistableErrors(), arguments.errorName);
	}
	
	// @hint this will tell us if any of the errors in VTResult or ErrorBean, do not have corispoding key in the persistanceOKList
	public boolean function isPersistable() {
		for(var errorName in getErrors()) {
			if(!arrayFind(getPersistableErrors(), errorName)) {
				return false;
			}
		}
		return true;
	}
	
	
	// @hint public helper method that delegates to isDeletable
	public boolean function isNotDeletable() {
		return !isDeletable();
	}
	
	
	// @hint public method that returns the value from the primary ID of this entity
	public string function getPrimaryIDValue() {
		return this.invokeMethod("get#getPrimaryIDPropertyName()#");
	}
	
	// @hint public method that returns the primary identifier column.  If there is no primary identifier column it throws an error
	public string function getPrimaryIDPropertyName() {
		return getService("utilityORMService").getPrimaryIDPropertyNameByEntityName( getEntityName() );
	}
	
	// @hint public method that returns and array of ID columns
	public any function getIdentifierColumnNames() {
		return getService("utilityORMService").getIdentifierColumnNamesByEntityName( getEntityName() );
	}
	
	// @hint public method that return the ID of the
	public any function getIdentifierValue() {
		var identifierColumns = getIdentifierColumnNames();
		var idValue = "";
		for(var i=1; i <= arrayLen(identifierColumns); i++){
			if(structKeyExists(variables, identifierColumns[i])) {
				idValue &= variables[identifierColumns[i]];
			}
		}
		return idValue;
	}
	
	// @hint public method that returns the full entityName as "Slatwallxxx"
	public string function getEntityName(){
		return getMetaData(this).entityname;
	}
	
	// @hint public method that overrides the standard getter so that null values won't be an issue
	public any function getCreatedDateTime() {
		if(isNull(variables.createdDateTime)) {
			return "";
		}
		return variables.createdDateTime;
	}
	
	// @hint public method that overrides the standard getter so that null values won't be an issue
	public any function getModifiedDateTime() {
		if(isNull(variables.modifiedDateTime)) {
			return "";
		}
		return variables.modifiedDateTime;
	}
	
	// @hint Generic abstract dynamic ORM methods by convention via onMissingMethod.
	public any function onMissingMethod(required string missingMethodName, required struct missingMethodArguments) {
		// hasUniqueXXX() 		Where XXX is a property to check if that property value is currenly unique in the DB
		if( left(arguments.missingMethodName, 9) == "hasUnique") {
			
			return getService("dataService").isUniqueProperty(propertyName=right(arguments.missingMethodName, len(arguments.missingMethodName) - 9), entity=this);
		
		// hasAnyXXX() 			Where XXX is one-to-many or many-to-many property and we want to see if it has any of an array of entities
		} else if( left(arguments.missingMethodName, 6) == "hasAny") {
			
			for(var object in arguments.missingMethodArguments[1]) {
				// evaluate is used instead of invokeMethod() because hasXXX() is an implicit orm function
				if( evaluate("has#right(arguments.missingMethodName, len(arguments.missingMethodName) - 6)#( object)") ){
					return true;
				}
			}
			return false;
		
		// getXXXOptions()		Where XXX is a one-to-many or many-to-many property that we need an array of valid options returned 		
		} else if ( left(arguments.missingMethodName, 3) == "get" && right(arguments.missingMethodName, 7) == "Options") {
			
			var cacheKey = right(arguments.missingMethodName, len(arguments.missingMethodName)-3);
			
			if(!structKeyExists(variables, cacheKey)) {
				variables[ cacheKey ] = [];
				
				var propertyName = left(cacheKey, len(cacheKey)-7);
				var entityService = getService("utilityORMService").getServiceByEntityName( getPropertyMetaData( propertyName ).cfc );
				var smartList = entityService.invokeMethod("get#getPropertyMetaData( propertyName ).cfc#SmartList", arguments.missingMethodArguments);
				
				var exampleEntity = createObject("component", "Slatwall.com.entity.#getPropertyMetaData( propertyName ).cfc#");
				
				smartList.addSelect(propertyIdentifier=exampleEntity.getSimpleRepresentationPropertyName(), alias="name");
				smartList.addSelect(propertyIdentifier=exampleEntity.getPrimaryIDPropertyName(), alias="value"); 
				smartList.addOrder("#exampleEntity.getSimpleRepresentationPropertyName()#|ASC");
				
				variables[ cacheKey ] = smartList.getRecords();
				
				// If this is a many-to-one related property, then add a 'select' to the top of the list
				if(getPropertyMetaData( propertyName ).fieldType == "many-to-one") {
					arrayPrepend(variables[ cacheKey ], {value="", name=rbKey('define.select')});	
				}
			}
			
			return variables[ cacheKey ];
		
		// getXXXSmartList()	Where XXX is a one-to-many or many-to-many property where we to return a smartList instead of just an array
		} else if ( left(arguments.missingMethodName, 3) == "get" && right(arguments.missingMethodName, 9) == "SmartList") {
			
			var cacheKey = right(arguments.missingMethodName, len(arguments.missingMethodName)-3);
			
			if(!structKeyExists(variables, cacheKey)) {
				variables[ cacheKey ] = [];
				
				var propertyName = left(cacheKey, len(cacheKey)-9);
				var entityService = getService("utilityORMService").getServiceByEntityName( getPropertyMetaData( propertyName ).cfc );
				var smartList = entityService.invokeMethod("get#getPropertyMetaData( propertyName ).cfc#SmartList", arguments.missingMethodArguments);
				
				// Create an example entity so that we can read the meta data
				var exampleEntity = createObject("component", "Slatwall.com.entity.#getPropertyMetaData( propertyName ).cfc#");
				
				// Loop over the properties in the example entity to 
				for(var i=1; i<=arrayLen(exampleEntity.getProperties()); i++) {
					if( structKeyExists(exampleEntity.getProperties()[i], "fkcolumn") && exampleEntity.getProperties()[i].fkcolumn == getPropertyMetaData( propertyName ).fkcolumn ) {
						smartList.addFilter("#exampleEntity.getProperties()[i].name#.#getPrimaryIDPropertyName()#", getPrimaryIDValue());
					}
				}
				
				variables[ cacheKey ] = smartList;
			}
			
			return variables[ cacheKey ];
		
		// getXXXStruct()		Where XXX is a one-to-many or many-to-many property where we want a key delimited struct
		} else if ( left(arguments.missingMethodName, 3) == "get" && right(arguments.missingMethodName, 6) == "Struct") {
			var cacheKey = right(arguments.missingMethodName, len(arguments.missingMethodName)-3);
			
			if(!structKeyExists(variables, cacheKey)) {
				variables[ cacheKey ] = {};
				
				var propertyName = left(cacheKey, len(cacheKey)-6);
				var values = this.invokeMethod("get#propertyName#");
				
				for(var i=1; i<=arrayLen(values); i++) {
					variables[cacheKey][ values[i].getPrimaryIDValue() ] = values[i];
				}
			}
			
			return variables[ cacheKey ];
			
		// getXXXCount()		Where XXX is a one-to-many or many-to-many property where we want to get the count of that property
		} else if ( left(arguments.missingMethodName, 3) == "get" && right(arguments.missingMethodName, 5) == "Count") {
			
			var propertyName = right(arguments.missingMethodName, len(arguments.missingMethodName)-3);
			propertyName = left(propertyName, len(propertyName)-5);
			
			return arrayLen(variabels[propertyName]);
		}
		
		throw( 'No matching method for #missingMethodName#().' );
	}	
	
	// ============ START: Non-Persistent Property Methods =================
	
	// ============  END:  Non-Persistent Property Methods =================
		
	// ============= START: Bidirectional Helper Methods ===================
	
	// =============  END:  Bidirectional Helper Methods ===================
	
	// ================== START: Overridden Methods ========================
	
	// ==================  END:  Overridden Methods ========================
		
	// =================== START: ORM Event Hooks  =========================
	
	public void function preInsert(){
		if(!this.isPersistable()) {
			throw("An ormFlush has been called on the hibernate session, however there is a #getEntityName()# entity in the hibernate session with errors");
		}
		
		var timestamp = now();
		
		if(structKeyExists(this,"setCreatedDateTime")){
			this.setCreatedDateTime(timestamp);
		}
		if(structKeyExists(this,"setCreatedByAccount")){
			setCreatedByAccount(getService("SessionService").getCurrentAccount());
		}
		
		if(structKeyExists(this,"setModifiedDateTime")){
			this.setModifiedDateTime(timestamp);
		}
		if(structKeyExists(this,"setModifiedByAccount")){
			setModifiedByAccount(getService("SessionService").getCurrentAccount());
		}
		
	}
	
	public void function preUpdate(struct oldData){
		if(!this.isPersistable()) {
			throw("An ormFlush has been called on the hibernate session, however there is a #getEntityName()# entity in the hibernate session with errors");
		}
		
		var timestamp = now();
		
		if(structKeyExists(this,"setModifiedDateTime")){
			this.setModifiedDateTime(timestamp);
		}
		if(structKeyExists(this,"setModifiedByAccount")){
			setModifiedByAccount(getService("SessionService").getCurrentAccount());
		}
	}
	
	public void function preDelete(any entity){

	}
	
	public void function preLoad(any entity){

	}
	
	public void function postInsert(any entity){

	}
	
	public void function postUpdate(any entity){

	}
	
	public void function postDelete(any entity){

	}
	
	public void function postLoad(any entity){

	}
	
	// ===================  END:  ORM Event Hooks  =========================
}
