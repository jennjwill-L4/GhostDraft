global class AutocreatedRegHandler1733848452015 implements Auth.SamlJitHandler {
	private class JitException extends Exception{}

	private static final String DEFAULT_ACCOUNT = '001S600000RALRqIAP';

	global User createUser(Id samlSsoProviderId, Id communityId, Id portalId,
			String federationIdentifier, Map<String, String> attributes, String assertion) {
		User u = new User();
		String contactHubId;
		String accountHubId;

		if(attributes.containsKey('Organization.Id')){
			accountHubId=attributes.get('Organization.Id');
		}
		if(attributes.containsKey('User.Id')){
			contactHubId=attributes.get('User.Id');
		}
		Account accountRecord;


		List<Account> acc=[SELECT Id, HUB_Account_ID__c, Type FROM Account WHERE HUB_Account_ID__c=:accountHubId LIMIT 1];

		if(acc.isEmpty()){
			accountRecord=[SELECT Id, HUB_Account_ID__c,Type FROM Account WHERE Id=:DEFAULT_ACCOUNT LIMIT 1];
		}
		else{
			accountRecord=acc[0];
		}


		Contact contactRecord;
		List<Contact> con=[SELECT Id, HUB_Contact_ID__c, Profile__c, FirstName, LastName, Email FROM Contact WHERE HUB_Contact_ID__c=:contactHubId LIMIT 1];

		if(con.isEmpty()){

			Contact c= new Contact();
			if(attributes.get('User.LastName')!=null){
				c.LastName=attributes.get('User.LastName');
			}
			if(attributes.get('User.FirstName')!=null){
				c.FirstName=attributes.get('User.FirstName');
			}
			if(attributes.get('User.Email')!=null){
				c.Email=attributes.get('User.Email');
			}
			if(accountRecord.Type!=null){
				c.Contact_Type__c=accountRecord.Type;
			}
			c.AccountId=accountRecord.Id;
			c.Profile__c='Customer Community Plus Login - Less Frequent';
			c.HUB_Contact_ID__c = contactHubId;
			try{
				insert c;
				contactRecord=c;
			}catch (Exception e) {
				throw new AuraHandledException('Error creating contact: ' + e.getMessage());
			}




		}
		else{
			if(con[0].Profile__c==null){
				con[0].Profile__c='Customer Community Plus Login - Less Frequent';
				contactRecord=con[0];
				try{
					update contactRecord;
				}catch (Exception e) {
					throw new AuraHandledException('Error updating profile of the contact: ' + e.getMessage());
				}
			}
			contactRecord=con[0];
		}

		List<User> existingUser = [SELECT Id, ContactId, email, firstName, lastName, FederationIdentifier FROM User WHERE ContactId = :contactRecord.Id LIMIT 1];
		if(existingUser.isEmpty())
		{
			Profile userProfile = [SELECT Id FROM Profile WHERE Name = 'Customer Community Plus Login - Less Frequent' LIMIT 1];
			System.Domain d = System.DomainParser.parse(URL.getOrgDomainUrl());
			User newUser = new User();
			if(attributes.get('User.Username')!=null){
				newUser.Username = attributes.get('User.Username')+'.'+d.getSandboxName();
			}
			newUser.Email = contactRecord.Email;
			newUser.FirstName = contactRecord.FirstName ;
			newUser.LastName = contactRecord.LastName;
			newUser.Alias = (contactRecord.FirstName != null ? contactRecord.FirstName.substring(0, 1) : '') + (contactRecord.LastName.length() >= 7 ? contactRecord.LastName.substring(0, 6) : contactRecord.LastName.substring(0));
			newUser.ProfileId = userProfile.Id;
			newUser.TimeZoneSidKey = 'America/Los_Angeles'; 
			newUser.LocaleSidKey = 'en_US'; 
			newUser.EmailEncodingKey = 'UTF-8';
			newUser.LanguageLocaleKey = 'en_US'; 
			newUser.ContactId = contactRecord.Id; 
			newUser.UserPermissionsSFContentUser = true;
			newUser.FederationIdentifier = federationIdentifier;
			try{
				insert newUser;
			}catch (Exception e) {
				throw new AuraHandledException('Error creating User: ' + e.getMessage());
			}
			insertPermissionSetAssignments(newUser.Id);
			return newUser;
		}
		else{

			if(existingUser[0].FederationIdentifier == null ) {
				existingUser[0].FederationIdentifier= federationIdentifier;
			}

			return existingUser[0];
		}


	}

	global void updateUser(Id userId, Id samlSsoProviderId, Id communityId, Id portalId,
			String federationIdentifier, Map<String, String> attributes, String assertion) {

		System.debug(attributes.get('Organization.Id'));
		System.debug(attributes.get('User.Id'));
		System.debug(JSON.serialize(attributes));

	}
	@future
	public static void insertPermissionSetAssignments(Id userId){
		List<PermissionSet> permissionSets = [SELECT Id FROM PermissionSet WHERE Name = 'Chatter_Permission_Set' OR Name ='fileUploadImproved'];
		if(!permissionSets.isEmpty()){
			List<PermissionSetAssignment> PermissionSetAssignments = new List<PermissionSetAssignment>();
			PermissionSetAssignment psa = new PermissionSetAssignment();
			psa.AssigneeId = userId;
			psa.PermissionSetId = permissionSets[0].Id;

			PermissionSetAssignments.add(psa);
			PermissionSetAssignment psa1 = new PermissionSetAssignment();
			psa1.AssigneeId = userId;
			psa1.PermissionSetId = permissionSets[1].Id;

			PermissionSetAssignments.add(psa1);

			try{
				insert PermissionSetAssignments;
			}catch (Exception e) {
				throw new AuraHandledException('Error creating PermissionSetAssignments: ' + e.getMessage());
			}
		}

	}

}