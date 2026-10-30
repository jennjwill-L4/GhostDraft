@isTest
private class AutocreatedRegHandlerTest {

    @testSetup
    public static void setupTestData() {
        Account acc = new Account();
        acc.Name='testsso';
        acc.HUB_Account_ID__c='1234';
        insert acc;
        Account acc1 = new Account();
        acc1.Name='testssoo';
        acc1.HUB_Account_ID__c='12345';
        insert acc1;
        Contact contactRecord = new Contact();
        contactRecord.LastName='testcontact123';
		
		contactRecord.FirstName='test121';
		
		contactRecord.HUB_Contact_ID__c='4567';
		contactRecord.Email='abdc@gmail.com';
		
		contactRecord.AccountId=acc1.Id;
		contactRecord.Contact_Type__c='Other';

        insert contactRecord;


        Contact contactRecord_1 = new Contact();
        contactRecord_1.LastName='testcontact1234';
		
		contactRecord_1.FirstName='test1214';
		
		contactRecord_1.HUB_Contact_ID__c='45674';
		contactRecord_1.Email='abdcde@gmail.com';
		
		contactRecord_1.AccountId=acc1.Id;
		contactRecord_1.Contact_Type__c='Other';

        insert contactRecord_1;

        Profile userProfile = [SELECT Id FROM Profile WHERE Name = 'Customer Community Plus Login - Less Frequent' LIMIT 1];

        System.Domain d = System.DomainParser.parse(URL.getOrgDomainUrl());
        user newUser= new user();
        newUser.Username = 'abc@gmail.com'+'.'+d.getSandboxName();
        newUser.Email = contactRecord_1.Email;
        newUser.FirstName = contactRecord_1.FirstName ;
        newUser.LastName = contactRecord_1.LastName;
        newUser.Alias = (contactRecord_1.FirstName != null ? contactRecord_1.FirstName.substring(0, 1) : '') + contactRecord_1.LastName.substring(0, 6);
        newUser.ProfileId = userProfile.Id;
        newUser.TimeZoneSidKey = 'America/Los_Angeles'; 
        newUser.LocaleSidKey = 'en_US'; 
        newUser.EmailEncodingKey = 'UTF-8';
        newUser.LanguageLocaleKey = 'en_US'; 
        newUser.ContactId = contactRecord_1.Id; 
        newUser.UserPermissionsSFContentUser = true; 
        insert newUser;
        
    }




    static testMethod void testCreateAndUpdateUser() {
        AutocreatedRegHandler1733848452015 handler = new AutocreatedRegHandler1733848452015();

        Account acc=[SELECT Id,HUB_Account_ID__c FROM Account WHERE Name='testsso' LIMIT 1];
        Contact c=[SELECT Id,HUB_Contact_ID__c FROM Contact WHERE LastName='testcontact123' LIMIT 1];
        Map<String, String> attributes= new Map<String, String>();
        attributes.put('Organization.Id',acc.HUB_Account_ID__c);
        attributes.put('User.LastName','test contact');
        attributes.put('User.FirstName','test');
        attributes.put('User.Email','abc@gmail.com');
        attributes.put('User.Username','testuser@testl4.com');
        attributes.put('User.Id',c.HUB_Contact_ID__c);
        System.Domain d = System.DomainParser.parse(URL.getOrgDomainUrl());

        Test.startTest();
        User u = handler.createUser(null, null,null,null,attributes,null);

        String uName='testuser@testl4.com.'+d.getSandboxName();
        System.assertEquals('abdc@gmail.com', u.email);
        System.assertEquals('testcontact123', u.lastName);
        System.assertEquals('test121', u.firstName);
        Contact con=[SELECT Id, HUB_Contact_ID__c, Profile__c FROM Contact WHERE Email='abdc@gmail.com' LIMIT 1];
        System.assertEquals('Customer Community Plus Login - Less Frequent', con.Profile__c);

        User userr=[SELECT Id, Username FROM User WHERE Username=:uName LIMIT 1];

        handler.updateUser(userr.Id,null,null,null,'99999',attributes,null);
        

        Map<String, String> attributes_1= new Map<String, String>();
        attributes_1.put('Organization.Id',acc.HUB_Account_ID__c);
        attributes_1.put('User.LastName','test contact test2');
        attributes_1.put('User.FirstName','test2');
        attributes_1.put('User.Email','abc@gmail.com');
        attributes_1.put('User.Username','testuser@test.com');

       

        User us = handler.createUser(null, null,null,null,attributes_1,null);
        System.assertEquals('abc@gmail.com', us.email);
        System.assertEquals('test contact test2', us.lastName);
        System.assertEquals('test2', us.firstName);

        Test.stopTest();
    }

}