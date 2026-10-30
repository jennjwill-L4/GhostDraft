@IsTest
private class HubLinkRedirectControllerTest {

    private static final String HUB_ID = 'b00384b6-391f-ee11-a9b9-002248219aae';
    private static final String USERNAME_DOMAIN = '@hubredirect.test';

    // Set this to the site's community profile name (Setup > Profiles).
    // If blank or not found, the test falls back to any customer community profile.
    private static final String COMMUNITY_PROFILE_NAME = 'Customer User'; // TODO this could be the incorrect profile but is in builder

    @TestSetup
    static void setup() {
        String suffix = String.valueOf(Datetime.now().getTime())
            + String.valueOf(Math.abs(Crypto.getRandomInteger()));

        // Community users' Account owner must have a role, so create an admin with one.
        User admin;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            UserRole role = new UserRole(Name = 'Hub Test Role', DeveloperName = 'HubTestRole' + suffix);
            insert role;

            admin = buildUser(adminProfileId(), 'HubAdminUser', suffix);
            admin.UserRoleId = role.Id;
            insert admin;
        }

        System.runAs(admin) {
            Account withHub = new Account(Name = 'Hub Test Account', HUB_Account_ID__c = HUB_ID);
            Account withoutHub = new Account(Name = 'No Hub Test Account');
            insert new List<Account>{ withHub, withoutHub };

            Contact hubContact = new Contact(LastName = 'HubContact', AccountId = withHub.Id);
            Contact noHubContact = new Contact(LastName = 'NoHubContact', AccountId = withoutHub.Id);
            insert new List<Contact>{ hubContact, noHubContact };

            Id portalProfileId = communityProfileId();

            User hubUser = buildUser(portalProfileId, 'HubPortalUser', suffix);
            hubUser.ContactId = hubContact.Id;

            User noHubUser = buildUser(portalProfileId, 'NoHubPortalUser', suffix);
            noHubUser.ContactId = noHubContact.Id;

            insert new List<User>{ hubUser, noHubUser };
        }
    }

    @IsTest
    static void returnsHubIdForCommunityUser() {
        User u = getTestUser('HubPortalUser');
        String result;

        Test.startTest();
        System.runAs(u) {
            result = HubLinkRedirectController.getHubAccountId();
        }
        Test.stopTest();

        Assert.areEqual(HUB_ID, result, 'Should return the HUB ID from the user\'s Contact > Account');
    }

    @IsTest
    static void returnsNullWhenAccountHasNoHubId() {
        User u = getTestUser('NoHubPortalUser');
        String result;

        Test.startTest();
        System.runAs(u) {
            result = HubLinkRedirectController.getHubAccountId();
        }
        Test.stopTest();

        Assert.isNull(result, 'Should return null when the Account has no HUB ID');
    }

    @IsTest
    static void returnsNullForInternalUser() {
        User u = getTestUser('HubAdminUser');
        String result;

        Test.startTest();
        System.runAs(u) {
            result = HubLinkRedirectController.getHubAccountId();
        }
        Test.stopTest();

        Assert.isNull(result, 'Internal users have no Contact, so no HUB ID');
    }

    // ---------- helpers ----------

    private static User getTestUser(String lastName) {
        String domainPattern = '%' + USERNAME_DOMAIN;
        return [
            SELECT Id FROM User
            WHERE LastName = :lastName AND Username LIKE :domainPattern
            LIMIT 1
        ];
    }

    private static User buildUser(Id profileId, String lastName, String suffix) {
        String uname = lastName.toLowerCase() + suffix + USERNAME_DOMAIN;
        return new User(
            ProfileId = profileId,
            LastName = lastName,
            Alias = lastName.left(8),
            Email = uname,
            Username = uname,
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/Chicago'
        );
    }

    private static Id adminProfileId() {
        return [
            SELECT Id FROM Profile
            WHERE UserType = 'Standard' AND PermissionsModifyAllData = true
            ORDER BY Name
            LIMIT 1
        ].Id;
    }

    private static Id communityProfileId() {
        if (String.isNotBlank(COMMUNITY_PROFILE_NAME)) {
            List<Profile> named = [SELECT Id FROM Profile WHERE Name = :COMMUNITY_PROFILE_NAME LIMIT 1];
            if (!named.isEmpty()) {
                return named[0].Id;
            }
        }
        List<Profile> portal = [
            SELECT Id FROM Profile
            WHERE UserType IN ('PowerCustomerSuccess', 'CustomerSuccess', 'CspLitePortal')
            ORDER BY UserType
            LIMIT 1
        ];
        Assert.isFalse(portal.isEmpty(), 'No customer community profile found. Set COMMUNITY_PROFILE_NAME.');
        return portal[0].Id;
    }
}