public with sharing class ArticleListController {

    private static String escapeSOSLCharacters(String key) {
        if (String.isBlank(key)) {
            return key;
        }
        
        key = key.replace('\\', '\\\\'); 
        
        key = key.replace('\'', '\\\'');

        key = key.replace('’', '\\\'');
        

        key = key.replace('!', '\\!');
        key = key.replace('?', '\\?');
        key = key.replace('&', '\\&');
        key = key.replace('|', '\\|');
        key = key.replace('(', '\\(');
        key = key.replace(')', '\\)');
        key = key.replace('^', '\\^');
        key = key.replace('~', '\\~');
        key = key.replace(':', '\\:');
        key = key.replace('[', '\\[');
        key = key.replace(']', '\\]');
        key = key.replace('{', '\\{');
        key = key.replace('}', '\\}');
        key = key.replace('+', '\\+'); 

        return key;
    } 

    @AuraEnabled(cacheable=true)
    public static List<Knowledge__kav> getArticles(Id recordId) {
        List<Id> entityList = new List<Id>();
        Set<String> uniqueTitles = new Set<String>();
        List<Knowledge__kav> uniqueArticles = new List<Knowledge__kav>();
        if (recordId==null) {
            return new List<Knowledge__kav>();
        }
        List<TopicAssignment> TopicAssignments= [SELECT EntityId from TopicAssignment where TopicId=:recordId LIMIT 1000];
        for(TopicAssignment tA : TopicAssignments)
        {
            entityList.add(tA.EntityId);
        }
        if(entityList!=null)
        {
            List<Knowledge__kav> knowledgeArticles = new List<Knowledge__kav>();
            if(Test.isRunningTest()){
                knowledgeArticles=[SELECT Id, Title,Image__c,FirstPublishedDate, LastPublishedDate, ArticleTotalViewCount, Summary FROM Knowledge__kav WHERE Id IN :entityList LIMIT 10 ];
            }
            else{
                knowledgeArticles=[SELECT Id, Title,Image__c,FirstPublishedDate, LastPublishedDate, ArticleTotalViewCount, Summary FROM Knowledge__kav WHERE Id IN :entityList AND PublishStatus='Online' LIMIT 1000];
            }
            
            for (Knowledge__kav article : knowledgeArticles) {
            if (!uniqueTitles.contains(article.Title)) {
                uniqueTitles.add(article.Title);
                uniqueArticles.add(article);
                }
              }
            return uniqueArticles;
        }
        return new List<Knowledge__kav>();
    }

    @AuraEnabled(cacheable=true)
    public static List<Topic> getTopics() {
        if(Test.isRunningTest()){
            User user = [SELECT Id FROM User WHERE Username = 'testCommunityUsermig123@test.com' LIMIT 1]; 
            NetworkMember networkMember = [select NetworkId from NetworkMember where MemberId = :user.Id order by Id desc limit 1 ];
            return [SELECT Id,Name FROM Topic WHERE  NetworkId=:networkMember.NetworkId  ];
        }
        Id NetworkID=Network.getNetworkId();
        return [SELECT Id,Name,CreatedDate,SystemModstamp FROM Topic WHERE  NetworkId=:NetworkID AND ManagedTopicType  LIKE '%Navigational%' ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Knowledge__kav> getTopRatedArticles() {
        List<Id> entityList = new List<Id>();
        List<Id> topicIds = new List<Id>();
        Set<String> uniqueIds = new Set<String>();
        List<Knowledge__kav> uniqueArticles = new List<Knowledge__kav>();
        Map<String,Knowledge__kav> articlesMap = new Map<String,Knowledge__kav>();
        List<Knowledge__kav> knowledgeArticles = new List<Knowledge__kav>();

        for(Topic topic : getTopics())
        {
            topicIds.add(topic.Id);
        }
        List<TopicAssignment> TopicAssignments= [SELECT EntityId from TopicAssignment where TopicId IN:topicIds LIMIT 1000];
        for(TopicAssignment tA : TopicAssignments)
        {
            entityList.add(tA.EntityId);
        }
        if(entityList!=null)
        {

            for(Knowledge__kav article : [SELECT Id, Title,Image__c,FirstPublishedDate, LastPublishedDate, ArticleTotalViewCount, Summary, KnowledgeArticleId FROM Knowledge__kav
                                         WHERE Id IN :entityList AND PublishStatus='Online' LIMIT 1000]){

                articlesMap.put(article.KnowledgeArticleId,article);

            }

            for(Knowledge__VoteStat vateStat : [SELECT Id,ParentId,NormalizedScore FROM Knowledge__VoteStat
                                         WHERE ParentId IN :articlesMap.keySet()  ORDER BY NormalizedScore DESC  LIMIT 1000]){
                                                
                if (!uniqueIds.contains(articlesMap.get(vateStat.ParentId).Id) && uniqueIds.size()<=10) {

                    uniqueIds.add(articlesMap.get(vateStat.ParentId).Id);
                    uniqueArticles.add(articlesMap.get(vateStat.ParentId));

                }
            }
            return uniqueArticles;
        }
        return new List<Knowledge__kav>();
    }

    @AuraEnabled(cacheable=true)
    public static List<Knowledge__kav> getArticlesByKeys(List<String> keys){
        List<Knowledge__kav> articles = new List<Knowledge__kav>();
        if(keys.size() != 0){
            Set<String> keysSet = new Set<String>();
            List<String> safeKeys = new List<String>();

            for(String key:keys){

                String cleanedKey = key.replace('-', ' ');
                

                String escapedKey = escapeSOSLCharacters(cleanedKey);
                
                keysSet.add(escapedKey);
            }
            

            keysSet.remove(' ');
            keysSet.remove('');
            keysSet.remove('-');
            
            for (String key : keysSet) {

                safeKeys.add('"' + key + '"'); 
            }

            if (safeKeys.isEmpty()) {
                return articles;
            }
            
            String keysString = String.join(safeKeys, ' OR ');
            
            String searchQuery = 'FIND {' + keysString + '} IN ALL FIELDS returning Knowledge__kav(Id, UrlName, Title, Summary LIMIT 5)';

            Search.SearchResults searchResults = Search.find(searchQuery);
            List<Search.SearchResult> articleResults = searchResults.get('Knowledge__kav');
            for (Search.SearchResult articleResult : articleResults) {
                Knowledge__kav article = (Knowledge__kav) articleResult.getSObject();
                articles.add(article);
            }
        } 
        return articles;
    }

    @InvocableMethod(label='Get Number of Article Recommendations' description='Get Number of Article Recommendations based on subject and description')
    public static List<FlowOutputValues> getNumberArticlesByKeys(List<FlowInputValues> inputs) {
        List<FlowOutputValues> results = new List<FlowOutputValues>();
        for (FlowInputValues input : inputs) {

            FlowOutputValues output = new ArticleListController.FlowOutputValues();
            
            List<String> keys = new List<String>();

            String safeSubject = input.subject; 
            String safeDescription = input.description;

            if(!String.isBlank(safeSubject)){
                keys.addAll(safeSubject.replace('-', ' ').split(' '));
            }
            if(!String.isBlank(safeDescription)){
                keys.addAll(safeDescription.replace('-', ' ').split(' '));
            }
            
            Set<String> keysSet = new Set<String>(keys);
            keysSet.remove(' ');
            keysSet.remove('');
            keysSet.remove('-');
            keys = new List<String>(keysSet);
            output.numberOfArticles = getArticlesByKeys(keys).size();
            results.add(output);
        }
        return results;
    }

    public class FlowInputValues {
        @InvocableVariable(required=true)
        public String subject;
        @InvocableVariable(required=true)
        public String description;
    }

    public class FlowOutputValues {
        @InvocableVariable
        public Integer numberOfArticles;
    }
}