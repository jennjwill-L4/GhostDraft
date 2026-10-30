public with sharing class CaseCommunicationController {
   public CaseCommunicationController() {


   }


   private static final String DEFAULT_NOTIFICATION_TEMPLATE = 'SUPPORT_Self_Service_New_Comment_Notification_L4';
   private static final String DEFAULT_EMAIL_TEMPLATE = 'New_Comment_Web';
   public static Boolean isRunningTest = false;


   public class FeedItemWrapper {
       @AuraEnabled
       public FeedItem feedItem { get; set; }
       @AuraEnabled
       public List<ContentVersion> contentVersions { get; set; }
   }


   //new wrapper for inline image support
   public class InlineImage {
       @AuraEnabled public String base64Data { get; set; }
       @AuraEnabled public String mimeType   { get; set; }
       @AuraEnabled public String fileName   { get; set; }
   }
    
   @AuraEnabled(cacheable=true)
   public static List<FeedItemWrapper> getFeedItems(Id recordId) {
       set<String> itemTypes= new Set<String>();
       itemTypes.add('ContentPost');
       itemTypes.add('CreateRecordEvent');
       itemTypes.add('TextPost');
       List<FeedItem> communications = new List<FeedItem>();
       Set<Id> entityIds = new Set<Id>();  
       List<FeedItem> FeedItems = new List<FeedItem>();
       if (!Test.isRunningTest()) {
           ConnectApi.FeedElementPage feedElementPage = ConnectApi.ChatterFeeds.getFeedElementsFromFeed(
               null,
               ConnectApi.FeedType.Record,
               recordId
           );
           for (ConnectApi.FeedElement element : feedElementPage.elements) {
                   entityIds.add(element.id);
           }


           FeedItems = [SELECT Id, ParentId, Body, CreatedDate, Type, CreatedBy.Name,
               (SELECT Id,RecordId, FeedEntityId, Title, Type
               FROM FeedAttachments)
               FROM FeedItem WHERE Id IN: entityIds AND Visibility ='AllUsers' AND Type IN: itemTypes ORDER BY Id DESC];
       } else{
           FeedItems = [SELECT Id, ParentId, Body, CreatedDate, Type, CreatedBy.Name,
               (SELECT Id,RecordId, FeedEntityId, Title, Type
               FROM FeedAttachments)
               FROM FeedItem WHERE ParentId =: recordId AND Visibility ='AllUsers' AND Type IN: itemTypes ORDER BY Id DESC];
       }
      
       Map<String, Set<id>> feedItemToContentVersions = new  Map<String, Set<id>>();
       Set<Id> versionIds = new Set<Id>();


       for (FeedItem item : FeedItems) {
           Set<Id> feedItemVersionIds = new Set<Id>();
           for(FeedAttachment attachment : item.FeedAttachments) {
               versionIds.add(attachment.RecordId);
               feedItemVersionIds.add(attachment.RecordId);
           }
           if(!feedItemToContentVersions.containsKey(item.Id)){
               feedItemToContentVersions.put(item.Id,feedItemVersionIds);
           }
       }


       List<ContentVersion> ContentVersions = [SELECT Id,Title,FileType,ContentDocumentId FROM ContentVersion WHERE Id IN :versionIds];
       Map<Id, ContentVersion> contentVersionsMap = new Map<Id, ContentVersion>(ContentVersions);
       List<FeedItemWrapper> feedItemWrappers = new List<FeedItemWrapper>();
       for (FeedItem item : FeedItems) {
           FeedItemWrapper FIW = new FeedItemWrapper();
           FIW.feedItem= item;
           FIW.contentVersions= new List<contentVersion>();
           for(Id contentVersionId:feedItemToContentVersions.get(item.Id)){
               ContentVersion cv = contentVersionsMap.get(contentVersionId);
               FIW.contentVersions.add(cv);
           }
           feedItemWrappers.add(FIW);
       }
       return feedItemWrappers;
   }


@AuraEnabled
   public static void createFeedItem(
       String bodyText,
       Id parentId,
       List<List<String>> fileIds,
       String communityId,
       List<InlineImage> inlineImages   // NEW
   ) {
       if (parentId == null) {
           throw new AuraHandledException('Parent ID cannot be null.');
       }


       Boolean hasFiles  = fileIds != null && !fileIds.isEmpty();
       Boolean hasImages = inlineImages != null && !inlineImages.isEmpty();


       String plainText = bodyText == null
           ? ''
           : bodyText.replaceAll('<[^>]+>', '').replace('&nbsp;', '').trim();


       String finalBody;
       if (String.isBlank(plainText)) {
           if (hasFiles || hasImages) {
               finalBody = null;
           } else {
               throw new AuraHandledException('Comment body cannot be empty.');
           }
       } else {
           finalBody = sanitizeForChatter(bodyText);
       }


       try {
           FeedItem feedItem = new FeedItem();
           feedItem.ParentId   = parentId;
           feedItem.Visibility = 'AllUsers';


           if (finalBody != null) {
               feedItem.Body       = finalBody;
               feedItem.IsRichText = true;
           } else {
               feedItem.Body = 'Attachment';
           }


           insert feedItem;


           List<FeedAttachment> links = new List<FeedAttachment>();


           // Existing uploaded files — unchanged behaviour
           if (hasFiles) {
               for (List<String> fileId : fileIds) {
                   FeedAttachment link = new FeedAttachment();
                   link.FeedEntityId = feedItem.Id;
                   link.RecordId     = Id.valueOf(fileId[1]);
                   link.Type         = 'CONTENT';
                   links.add(link);
               }
           }


           //decode pasted base64 images into ContentVersion records
           if (hasImages) {
               List<ContentVersion> newVersions = new List<ContentVersion>();
               for (InlineImage img : inlineImages) {
                   if (String.isBlank(img.base64Data)) continue;


                   ContentVersion cv = new ContentVersion();
                   cv.Title                    = img.fileName;
                   cv.PathOnClient             = img.fileName;
                   cv.VersionData              = EncodingUtil.base64Decode(img.base64Data);
                   cv.FirstPublishLocationId   = parentId;   // links the file to the Case
                   newVersions.add(cv);
               }


               if (!newVersions.isEmpty()) {
                   insert newVersions;


                   for (ContentVersion cv : newVersions) {
                       FeedAttachment link = new FeedAttachment();
                       link.FeedEntityId = feedItem.Id;
                       link.RecordId     = cv.Id;
                       link.Type         = 'CONTENT';
                       links.add(link);
                   }
               }
           }


           if (!links.isEmpty()) {
               insert links;
           }


       } catch (Exception ex) {
           System.debug(ex.getMessage());
           throw new AuraHandledException('Error creating FeedItem: ' + ex.getMessage());
       }
   }


   public static void notifyUsers(List<FeedItem> FeedItems) {
           //Only process FeedItems whose parent is a Case
           List<FeedItem> caseFeedItems = new List<FeedItem>();
           Set<String> parentIds = new Set<String>();
               for (FeedItem comment : FeedItems) {
                   if (comment.ParentId != null && comment.ParentId.getSObjectType() == Case.SObjectType) {
                       caseFeedItems.add(comment);
                       parentIds.add(comment.ParentId);
                   }
           }


           // Nothing relevant — exit early (prevents the NPE on non-Case parents)
           if (caseFeedItems.isEmpty()) {
                   return;
           }
  
       CustomNotificationType notificationType = [SELECT Id, DeveloperName FROM CustomNotificationType WHERE CustomNotifTypeName = 'PushNotification'];
       //List<String> parentIds=  new List<String>();
       // for (FeedItem comment : FeedItems) {
       //     parentIds.add(comment.parentId);
       // }
       Map<Id,Case> caseMap =new Map<ID, Case>([SELECT Id, OwnerId ,CreatedById, caseNumber, Subject, Case_URL_formula__c
                   FROM Case
                   WHERE Id IN:parentIds]);


       EmailTemplate notificationTemplate =[SELECT Id, Subject ,HTMLValue, DeveloperName, Body
           FROM EmailTemplate
           WHERE DeveloperName =:DEFAULT_NOTIFICATION_TEMPLATE];
       EmailTemplate emailTemplate =[SELECT Id, Subject ,HTMLValue, DeveloperName
           FROM EmailTemplate
           WHERE DeveloperName =:DEFAULT_EMAIL_TEMPLATE];


    Map<Id, String> userEmailMap = new Map<Id, String>();
       for (User user : [SELECT Id, Email, Contact.Email FROM User]) {
           String resolvedEmail = (user.Contact != null && String.isNotBlank(user.Contact.Email))
               ? user.Contact.Email
               : user.Email;
           userEmailMap.put(user.Id, resolvedEmail);
       }
       
       List<EmailWrapper> Emails = new List<EmailWrapper>();
       List<Messaging.CustomNotification> notifications = new  List<Messaging.CustomNotification>();
       // for (FeedItem comment : FeedItems) {
       for (FeedItem comment : caseFeedItems) {
           System.debug('===> '+comment.ParentId+' '+comment.Visibility+' '+Id.valueOf(caseMap.get(comment.ParentId).CreatedById)+' '+UserInfo.getUserId());
           if (comment.ParentId != null && comment.Visibility =='AllUsers' && (Id.valueOf(caseMap.get(comment.ParentId).CreatedById) != UserInfo.getUserId() || isRunningTest) ) {
               Messaging.CustomNotification notification = new Messaging.CustomNotification();
               String notificationBody = notificationTemplate.Body;
               String notificationSubject = notificationTemplate.Subject;


               if(caseMap.get(comment.ParentId).caseNumber!=null){
                   notificationBody=notificationBody.replace('{!Case.Subject}', caseMap.get(comment.ParentId).Subject);
                   notificationBody=notificationBody.replace('{!Case.CaseNumber}', caseMap.get(comment.ParentId).caseNumber);
                   notificationSubject=notificationSubject.replace('{!Case.CaseNumber}',caseMap.get(comment.ParentId).caseNumber);
               }
              
               notification.setTitle(notificationSubject);
               notification.setBody(notificationBody);
               notification.setNotificationTypeId(notificationType.Id);
               notification.setTargetId(comment.ParentId);
              
               try {
                   if(caseMap.get(comment.ParentId).CreatedById!=null){
                       String userId= Id.valueOf(caseMap.get(comment.ParentId).CreatedById);
                       notification.send(new set<String>{userId});
                       EmailWrapper email = new EmailWrapper();
                       email.userId = userId;
                       email.caseRecord = caseMap.get(comment.ParentId);
                       Emails.add(email);
                   }
               }
               catch (Exception e) {
                   System.debug('Problem sending notification: ' + e.getMessage());
               }
           }
       }
       update caseMap.values();
       sendEmail(emailTemplate, userEmailMap, Emails);
   }


   public static void sendEmail(EmailTemplate emailTemplate, Map<Id, String> users, List<EmailWrapper> emails){
           if (emails == null || emails.isEmpty()) {
       return;
   }


   try{
       Messaging.reserveSingleEmailCapacity(2);
       List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
       for(EmailWrapper email: emails){
           Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
           String[] toAddresses = new String[] {users.get(email.userId)};


           mail.setToAddresses(toAddresses);
           OrgWideEmailAddress[] owea = [SELECT Id FROM OrgWideEmailAddress WHERE Address = 'support@ghostdraft.com'];
           if ( owea.size() > 0 ) {
               mail.setOrgWideEmailAddressId(owea.get(0).Id);
           }
           String body = emailTemplate.HTMLValue;
           String subject = emailTemplate.Subject;


           if(email.caseRecord.caseNumber!=null){
               body = body.replace('{!Case.CaseNumber}', email.caseRecord.caseNumber);
               body = body.replace('{!Case.Case_URL_formula__c}', email.caseRecord.Case_URL_formula__c);
               subject = subject.replace('{!Case.CaseNumber}',email.caseRecord.caseNumber);
           }


           if(email.caseRecord.Subject != null){
               body = body.replace('{!Case.Subject}', email.caseRecord.Subject);
           }


           mail.setSubject(subject);
           mail.setBccSender(false);
           mail.setUseSignature(false);
           //mail.setPlainTextBody(body);
           mail.setHtmlBody(body);
           mails.add(mail);
       }
       Messaging.sendEmail(mails);
      
   }catch (Exception e) {
       System.debug('Email send skipped/failed (non-fatal): ' + e.getMessage());
   }
}


private static String sanitizeForChatter(String html) {
       if (String.isBlank(html)) return html;


       // 1. Semantic tag conversion
       html = html.replaceAll('(?i)<strong(\\s[^>]*)?>', '<b>').replaceAll('(?i)</strong>', '</b>');
       html = html.replaceAll('(?i)<em(\\s[^>]*)?>', '<i>').replaceAll('(?i)</em>', '</i>');
       html = html.replaceAll('(?i)<del(\\s[^>]*)?>', '<s>').replaceAll('(?i)</del>', '</s>');


       // 2. div → p
       html = html.replaceAll('(?i)<div[^>]*>', '<p>').replaceAll('(?i)</div>', '</p>');


       // 3. Convert Quill indent classes to nested <blockquote> — a whitelisted TAG.
       html = html.replaceAll('(?is)<p[^>]*class="[^"]*ql-indent-4[^"]*"[^>]*>(.*?)</p>',
           '<blockquote><blockquote><blockquote><blockquote><p>$1</p></blockquote></blockquote></blockquote></blockquote>');
       html = html.replaceAll('(?is)<p[^>]*class="[^"]*ql-indent-3[^"]*"[^>]*>(.*?)</p>',
           '<blockquote><blockquote><blockquote><p>$1</p></blockquote></blockquote></blockquote>');
       html = html.replaceAll('(?is)<p[^>]*class="[^"]*ql-indent-2[^"]*"[^>]*>(.*?)</p>',
           '<blockquote><blockquote><p>$1</p></blockquote></blockquote>');
       html = html.replaceAll('(?is)<p[^>]*class="[^"]*ql-indent-1[^"]*"[^>]*>(.*?)</p>',
           '<blockquote><p>$1</p></blockquote>');


       // 4. Strip span tags but keep content
       html = html.replaceAll('(?i)<span[^>]*>', '').replaceAll('(?i)</span>', '');


       // 5. Strip ALL disallowed attributes including style — Chatter rejects style outright
       html = html.replaceAll('(?i)\\s(style|class|id|align|width|height|data-[\\w-]+)=["\'][^"\']*["\']', '');


       // 6. Strip any remaining img tags (base64 ones extracted client-side)
       html = html.replaceAll('(?i)<img[^>]*/?>', '');


       // 7. Empty paragraphs Salesforce rejects
       html = html.replaceAll('(?i)<p[^>]*>\\s*<br\\s*/?>\\s*</p>', '');
       html = html.replaceAll('(?i)<p[^>]*>\\s*</p>', '');


       // 8. Standalone <br>
       html = html.replaceAll('(?i)<br\\s*/?>', '<p></p>');


       // 9. Strip unsupported tags, keep inner content
       html = html.replaceAll(
           '(?i)<(?!/?\\s*(p|b|i|u|s|ul|ol|li|a|h[1-4]|blockquote|pre|sub|sup)(\\s|>|/))[^>]+>',
           ''
       );


       // 10. Clean up empty paragraphs introduced by step 9
       html = html.replaceAll('(?i)<p[^>]*>\\s*</p>', '');


       return html;
   }




   public class EmailWrapper{
       public String userId;
       public Case caseRecord;
   }


}