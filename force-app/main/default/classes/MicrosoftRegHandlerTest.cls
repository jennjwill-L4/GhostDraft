@isTest
private class MicrosoftRegHandlerTest {

    @testSetup
    static void setupTestData() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Customer Community Plus' LIMIT 1];

        Account a = new Account(Name = 'Test SSO Account');
        insert a;
        
        Contact c = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            AccountId = a.Id
        );
        insert c;
        
        User u = new User(
            FirstName = 'Test',
            LastName = 'User',
            Username = 'test.user@domain.com',
            Email = 'test.user@domain.com',
            Alias = 'tuser',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ContactId = c.Id
        );
        insert u;
    }

    @isTest
    static void testCreateUser_NewUser() {
        Auth.UserData userData = new Auth.UserData(
            'new.user@domain.com',
            'New',
            'User',
            'New User',
            'new.user@domain.com',
            null,
            'new.user@domain.com',
            null,
            null,
            null,
            new Map<String, String>{ 'unique_name' => 'new.user@domain.com' }
        );

        MicrosoftRegHandler handler = new MicrosoftRegHandler();
        User newUser = handler.createUser(null, userData);


        System.assertEquals('New', newUser.FirstName);
        System.assertEquals('User', newUser.LastName);
        System.assertEquals('new.user@domain.com', newUser.Email);
        System.assertEquals('new.user@domain.com', newUser.Username);
        System.assertEquals('New', newUser.Alias);
        System.assertNotEquals(null, newUser.ContactId);
    }

    @isTest
    static void testCreateUser_ExistingUser() {
        Auth.UserData userData = new Auth.UserData(
            'test.user@domain.com',
            'Test',
            'User',
            'Test User',
            'test.user@domain.com',
            null,
            'test.user@domain.com',
            null,
            null,
            null,
            new Map<String, String>{ 'unique_name' => 'test.user@domain.com' }
        );

        MicrosoftRegHandler handler = new MicrosoftRegHandler();
        User existingUser = handler.createUser(null, userData);

        System.assertNotEquals(null, existingUser.Id);
        System.assertEquals('test.user@domain.com', existingUser.Email);
    }

    @isTest
    static void testUpdateUser() {
        User testUser = [SELECT Id, FirstName, LastName, Email FROM User WHERE Email = 'test.user@domain.com' LIMIT 1];

        Auth.UserData userData = new Auth.UserData(
            'updated.user@domain.com',
            'Updated',
            'User',
            'Updated User',
            'updated.user@domain.com',
            null,
            'updated.user@domain.com',
            null,
            null,
            null,
            new Map<String, String>{ 'unique_name' => 'updated.user@domain.com' }
        );

        MicrosoftRegHandler handler = new MicrosoftRegHandler();
        handler.updateUser(testUser.Id, null, userData);

        User updatedUser = [SELECT Id, FirstName, LastName, Email FROM User WHERE Id = :testUser.Id];

        System.assertEquals('Updated', updatedUser.FirstName);
        System.assertEquals('User', updatedUser.LastName);
        System.assertEquals('updated.user@domain.com', updatedUser.Email);
    }
}