public with sharing class CometDController {
    @AuraEnabled(cacheable=true)
    public static String getSessionId() {
    return UserInfo.getSessionId();
    }
}