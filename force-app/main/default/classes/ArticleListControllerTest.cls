@isTest
public with sharing class ArticleListControllerTest {

    @testSetup
    public static void setupTestData() {
        Id profileId = [select id from profile where name= 'Customer Community Plus Login - Less Frequent'].id;
        UserRole userrole = [Select Id, DeveloperName From UserRole Where DeveloperName = 'CEO' Limit 1];

        User adminUser = [Select Id, UserRoleId From User Where Profile.Name='System Administrator' AND IsActive=true AND UserPermissionsKnowledgeUser = true Limit 1];

        adminUser.UserRoleId = userRole.Id;
        update adminUser;
        System.runAs(adminUser) {
            Account acc = new Account(name = 'test') ;
            insert acc;

            Contact con = new Contact(LastName = 'Test_Contact'
            ,AccountId = acc.Id
            ,Email = 'testCommunityUsermig123@test.com'
            ,Title = 'Journalist');
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
        
            User user = [SELECT Id FROM User WHERE Username = 'testCommunityUsermig123@test.com']; 
       
            NetworkMember networkMember = [select NetworkId from NetworkMember where MemberId = :User.Id order by Id desc limit 1 ];
            
            
            Knowledge__kav article1 = new Knowledge__kav(Title = 'Article 1', Summary = 'Summary 1', UrlName='testurl1');
            Knowledge__kav article2 = new Knowledge__kav(Title = 'Article 2', Summary = 'Summary 2', UrlName='testurl2');
            Knowledge__kav article3 = new Knowledge__kav(Title = 'Article 3', Summary = 'Summary 3', UrlName='testurl3'); 
            
            List<Knowledge__kav> articles =  new List<Knowledge__kav>{article1, article2, article3};
            insert articles;
            set<Id> articleId= new set<Id>();
            for (Knowledge__kav article : articles)
            {
                articleId.add(article.Id);
            }
            
            List<Knowledge__kav> knowledgeArticleIds = [SELECT Id,Title,KnowledgeArticleId FROM Knowledge__kav WHERE Id IN:articleId LIMIT 10];
            for (Knowledge__kav kn : knowledgeArticleIds)
            {           
                KbManagement.PublishingService.publishArticle(kn.KnowledgeArticleId, true);
                
            }
            
            
            Topic topic1 = new Topic(Name = 'Topic 1',NetworkId=networkMember.NetworkId);
            insert topic1;
            Topic topic2 = new Topic(Name = 'Topic 2',NetworkId=networkMember.NetworkId);
            insert topic2;
            TopicAssignment topicAssignment1 = new TopicAssignment(TopicId = topic1.Id, EntityId = article1.Id);
            TopicAssignment topicAssignment2 = new TopicAssignment(TopicId = topic1.Id, EntityId = article2.Id);
            TopicAssignment topicAssignment3 = new TopicAssignment(TopicId = topic1.Id, EntityId = article3.Id); 
            
            insert new List<TopicAssignment>{topicAssignment1, topicAssignment2, topicAssignment3};
        }
           
            
        
    }

    @isTest
    public static void testGetArticles() {

        
        User user = [SELECT Id FROM User WHERE Username = 'testCommunityUsermig123@test.com'];
            Topic testTopic = [SELECT Id FROM Topic WHERE NAME = 'Topic 1'];
            Test.startTest();
            List<Knowledge__kav> articles = ArticleListController.getArticles(testTopic.Id);
            Test.stopTest();
            System.assertEquals(3, articles.size());
      
    }
    

    @isTest
    public static void testGetTopics() {
        User user = [SELECT Id FROM User WHERE Username = 'testCommunityUsermig123@test.com']; 
        System.runAs(user) {
                    Test.startTest();
                    List<Topic> topics = ArticleListController.getTopics();
                    Test.stopTest();
                    System.assertEquals(2, topics.size());
        }
    }
    @isTest
    public static void testTopRatedArticles() {
        User user = [SELECT Id FROM User WHERE Username = 'testCommunityUsermig123@test.com']; 
        System.runAs(user) {
                    Test.startTest();
                    List<Knowledge__kav> articles = ArticleListController.getTopRatedArticles();
                    Test.stopTest();
                    System.assertEquals(0, articles.size());
        }
    }

    @isTest
    public static void testGetArticlesByKeys() {
        List<Knowledge__kav> articleResults = [SELECT Id FROM Knowledge__kav];
        Test.setFixedSearchResults(new List<Id>(new Map<Id, Knowledge__kav>(articleResults).keySet()));
        Test.startTest();
        List<Knowledge__kav> articles = ArticleListController.getArticlesByKeys(new List<String>{'article'});
        Test.stopTest();
        System.assertEquals(3, articles.size());
    }

    @isTest
    public static void testGetNumberArticlesByKeys() {
        ArticleListController.FlowInputValues input = new ArticleListController.FlowInputValues();
        input.subject = 'Article';
        input.description = 'Article';
        List<Knowledge__kav> articleResults = [SELECT Id FROM Knowledge__kav];
        Test.setFixedSearchResults(new List<Id>(new Map<Id, Knowledge__kav>(articleResults).keySet()));
        Test.startTest();
        List<ArticleListController.FlowOutputValues> flowOutputValues = ArticleListController.getNumberArticlesByKeys(new List<ArticleListController.FlowInputValues>{input});
        Test.stopTest();
        System.assertEquals(3, flowOutputValues[0].numberOfArticles);
    }
}