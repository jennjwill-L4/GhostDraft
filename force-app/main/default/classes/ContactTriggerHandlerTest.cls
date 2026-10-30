@isTest
private class ContactTriggerHandlerTest {

    @isTest(seeAllData=false)
    public static void testContactHandler() {
        Id profileId = [select id from profile where name= 'Customer Community Plus Login - Less Frequent'].id;
        Id newProfileId = [select id from profile where name= 'Customer Community Plus - Frequent'].id;
        UserRole userrole = [Select Id, DeveloperName From UserRole Where DeveloperName = 'CEO' Limit 1];

        User adminUser = [Select Id, UserRoleId From User Where Profile.Name='System Administrator' AND IsActive=true Limit 1];

        adminUser.UserRoleId = userRole.Id;
        update adminUser;
        System.runAs(adminUser) {
            Account acc = new Account(name = 'test') ;
            insert acc;

            Contact con = new Contact(LastName = 'Test_Contact'
            ,AccountId = acc.Id
            ,Email = 'testCommunityUsermig123@test.com'
            ,Title = 'Journalist'
            ,Profile__c='Customer Community Plus Login - Less Frequent');
            insert con;
            
            User communityUser = new User(alias = 'comUser'
            ,email = 'testCommunityUsermig123@test.com'
            ,emailencodingkey='UTF-8'
            ,lastname = 'Batman'
            ,languagelocalekey='en_US'
            ,localesidkey='en_US'
            ,profileid = profileId
            ,country = 'France'
            ,IsActive = true
            ,ContactId = con.Id
            ,timezonesidkey='America/Los_Angeles'
            ,UserPermissionsSFContentUser = true
            ,username = 'testCommunityUsermig123@test.com');
            insert communityUser;
            
            Test.startTest();
            con.Profile__c='Customer Community Plus - Frequent';
            update con;
            Test.stopTest();
        }
        User u =[SELECT id, ProfileId FROM USER WHERE username= 'testCommunityUsermig123@test.com'];
        System.assertEquals(newProfileId,u.ProfileId);
    }

}