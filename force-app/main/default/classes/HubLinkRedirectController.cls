/**
 * Returns the logged-in community user's Hub Account ID
 * (User > Contact > Account > HUB_Account_ID__c) for the hubLinkRedirect LWC.
 *
 * Runs without sharing and WITH SYSTEM_MODE on purpose: it only ever reads the
 * current user's own Account, and this avoids depending on sharing or
 * field-level security for HUB_Account_ID__c on the community profiles.
 * WITH SYSTEM_MODE is required at API version 67.0+, where Apex runs in user
 * mode by default and would otherwise enforce the community user's FLS.
 */
public without sharing class HubLinkRedirectController {

    @AuraEnabled(cacheable=true)
    public static String getHubAccountId() {
        List<User> users = [
            SELECT ContactId, Contact.Account.HUB_Account_ID__c
            FROM User
            WHERE Id = :UserInfo.getUserId()
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        // Internal users (e.g. admins in Experience Builder) have no Contact.
        if (users.isEmpty() || users[0].ContactId == null || users[0].Contact.Account == null) {
            return null;
        }
        return users[0].Contact.Account.HUB_Account_ID__c;
    }
}