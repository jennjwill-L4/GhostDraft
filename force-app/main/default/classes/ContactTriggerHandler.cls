public with sharing class ContactTriggerHandler {
    public ContactTriggerHandler() {

    }

    public static void updateUser(List<Contact> contacts, Map<Id,Contact> oldMapContacts){
        List<String> contactIds = new List<String>();

        for(Contact c :contacts){
            contactIds.add(c.Id);
        }

        List<User> users = [SELECT  Id, Name, ProfileId,ContactId FROM USER WHERE ContactId IN:contactIds];

        Map<String, User> mapUsersWithContacts = new Map<String, User>();

        for(User u:users){
            mapUsersWithContacts.put(u.ContactId,u);
        }

        List<Profile> profiles = [SELECT  Id, Name FROM Profile];

        Map<String, String> mapProfileWithName = new Map<String, String>();

        for(Profile p:profiles){
            mapProfileWithName.put(p.Name,p.Id);
        }

        List<Id> updatedUsers = new List<Id>();
        Map<Id,String> mapProfiles = new Map<Id, String>();
        for(Contact c: contacts){
            if(c.Profile__c!=oldMapContacts.get(c.Id).Profile__c && mapUsersWithContacts.get(c.Id)!=null){
                User u = mapUsersWithContacts.get(c.Id);
                u.ProfileId=mapProfileWithName.get(c.Profile__c);
                updatedUsers.add(u.Id);
                mapProfiles.put(u.Id,mapProfileWithName.get(c.Profile__c));
            }
        }
        if(updatedUsers.size()>0){
            updateUsersWithProfiles(updatedUsers,mapProfiles);
        }
        
    }
    @future
    public static void updateUsersWithProfiles(List<Id> usersId, Map<Id,String> mapProfiles){

        List<User> users = [SELECT  Id, Name, ProfileId,ContactId FROM USER WHERE Id IN:usersId];
        List<User> updatedList =new List<User>();

        for(User u: users){
            u.profileId=mapProfiles.get(u.Id);
            updatedList.add(u);
        }

        update updatedList;

    }
}