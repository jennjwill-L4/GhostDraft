global class MicrosoftRegHandler implements Auth.RegistrationHandler {

    global User createUser(Id portalId, Auth.UserData data) {
        List<User> users = [SELECT Id, Username, Email, FirstName, LastName FROM User WHERE Email = :data.attributeMap.get('unique_name')];
        if(users.size() == 1) {
            return users.get(0);
        }
        
        Account a;
        List<Account> accounts = [SELECT Id FROM account WHERE name=:'Test SSO Account'];
        if(accounts.isEmpty()){
            a = new Account(name ='Test SSO Account');
            insert(a);
        }else {
            a = accounts[0];
        }
      
        Contact c = new Contact();
        c.accountId = a.Id;
  
        c.firstName = data.firstName;
        c.lastName  = data.lastName;
        insert(c);
       
       
        User u = new User();
        Profile p = [SELECT Id FROM profile WHERE name='Customer Community Plus'];
        u.username = data.attributeMap.get('unique_name');
        u.email = data.attributeMap.get('unique_name');
        u.lastName = data.lastName;
        u.firstName = data.firstName;
        String alias = data.firstName;
        //Alias must be 8 characters or less
        if(alias.length() > 8) {
            alias = alias.substring(0, 8);
        }
        u.alias = alias;
        u.languagelocalekey = UserInfo.getLocale();
        u.localesidkey = UserInfo.getLocale();
        u.emailEncodingKey = 'UTF-8';
        u.timeZoneSidKey = 'America/Los_Angeles';
        u.profileId = p.Id;
        u.contactId = c.Id;
        return u;
    }

    global void updateUser(Id userId, Id portalId, Auth.UserData data){
     
      User u = new User(id=userId);
         
      if(data.email != null && data.email != '') {
          u.email = data.email;
      }
         
      if(data.lastName != null && data.lastName != '') {
        u.lastName = data.lastName;
      }
      
      if(data.firstName != null && data.firstName != '') {
        u.firstName = data.firstName;
      }
      
      update(u);
    } 
}