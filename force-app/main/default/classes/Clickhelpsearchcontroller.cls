public with sharing class Clickhelpsearchcontroller {

    private static final String CLICKHELP_NC = 'callout:ClickHelp_Search';
    private static final Set<String> ALLOWED_LIBRARY_NAMES = new Set<String>{
        'Desktop Tools (Studio and Data Workbench)',
        'Server Downloads',
        'GBLI Bureau Content',
        'GNY Bureau Content',
        'Lio Bureau Content',
        'Markel Bureau Content',
        'Universal Bureau Content'
    };

    @AuraEnabled
    public static SearchResponse search(String term) {
        SearchResponse resp = new SearchResponse();
        if (String.isBlank(term)) return resp;
        String cleanTerm = term.trim();
        String soslTerm = sanitizeForSosl(cleanTerm);

        resp.articles = new ArticleFetcher().fetch(cleanTerm);
        new CaseSearcher().doSearch(soslTerm, resp);
        new FileSearcher().doSearch(soslTerm, resp);

        return resp;
    }

    private without sharing class ArticleFetcher {
    public List<Article> fetch(String term) {
        List<Article> articles = new List<Article>();
        try {
            HttpRequest req = new HttpRequest();
            req.setMethod('GET');
            req.setHeader('Accept', 'application/json');
            req.setTimeout(120000);
            req.setEndpoint(
                CLICKHELP_NC + '/api/v1/search'
                + '?count=-1'
                + '&isReturnSnippets=1'
                + '&q=' + EncodingUtil.urlEncode(term, 'UTF-8')
            );
            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() == 200) {
                List<Article> parsed =
                    (List<Article>) JSON.deserialize(res.getBody(), List<Article>.class);
                for (Article a : parsed) {
                    if (String.isNotBlank(a.fullUrl)) articles.add(a);
                }
            } else {
                System.debug(LoggingLevel.WARN,
                    'ClickHelp HTTP ' + res.getStatusCode() + ': ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'ClickHelp callout: ' + e.getMessage());
        }
        return articles;
    }
}

    private without sharing class CaseSearcher {
    public void doSearch(String soslTerm, SearchResponse resp) {
        if (String.isBlank(soslTerm) || soslTerm.length() < 2) return;

        User runningUser = [SELECT ContactId, UserType FROM User 
                           WHERE Id = :UserInfo.getUserId() LIMIT 1];

        List<List<SObject>> found;

        if (runningUser.UserType == 'Standard') {
            // Internal user — show all matching cases
            found = [
                FIND :soslTerm IN NAME FIELDS RETURNING
                    Case(Id, CaseNumber, Subject, Status, CreatedDate
                    WHERE Origin = 'Web'
                         ORDER BY CreatedDate DESC LIMIT 200)
            ];
        } else if (runningUser.ContactId != null) {
            // Community/portal user — show only their cases
            Id contactId = runningUser.ContactId;
            found = [
                FIND :soslTerm IN NAME FIELDS RETURNING
                    Case(Id, CaseNumber, Subject, Status, CreatedDate
                         WHERE ContactId = :contactId AND Origin = 'Web'
                         ORDER BY CreatedDate DESC LIMIT 200)
            ];
        } else {
            return; // No ContactId, no cases
        }

        for (Case c : (List<Case>) found[0]) {
            resp.cases.add(new CaseResult(c));
        }
    }
}

private with sharing class FileSearcher {
    public void doSearch(String soslTerm, SearchResponse resp) {
        if (String.isBlank(soslTerm) || soslTerm.length() < 2) return;

        List<List<SObject>> found = [
            FIND :soslTerm IN NAME FIELDS RETURNING
                ContentVersion(Id, ContentDocumentId, Title, FileExtension,
                               ContentSize, LastModifiedDate
                               WHERE IsLatest = true LIMIT 200)
        ];

        List<ContentVersion> cvList = (List<ContentVersion>) found[0];
        if (cvList.isEmpty()) return;

        Set<Id> docIds = new Set<Id>();
        for (ContentVersion cv : cvList) {
            docIds.add(cv.ContentDocumentId);
        }

        Set<Id> keepDocIds = new Set<Id>();

        // 1) Files living in a whitelisted library (excludes Asset Library).
        Set<Id> allowedLibraryIds = new Set<Id>();
        for (ContentWorkspace lib : [
            SELECT Id FROM ContentWorkspace WHERE Name IN :ALLOWED_LIBRARY_NAMES
        ]) {
            allowedLibraryIds.add(lib.Id);
        }

        if (!allowedLibraryIds.isEmpty()) {
            for (ContentDocumentLink cdl : [
                SELECT ContentDocumentId
                FROM ContentDocumentLink
                WHERE ContentDocumentId IN :docIds
                AND LinkedEntityId IN :allowedLibraryIds
            ]) {
                keepDocIds.add(cdl.ContentDocumentId);
            }
        }

        Set<Id> caseIds = new Set<Id>();
        for (Case c : [SELECT Id FROM Case LIMIT 2000]) {
            caseIds.add(c.Id);
        }

        if (!caseIds.isEmpty()) {
            for (ContentDocumentLink cdl : [
                SELECT ContentDocumentId
                FROM ContentDocumentLink
                WHERE ContentDocumentId IN :docIds
                AND LinkedEntityId IN :caseIds
            ]) {
                keepDocIds.add(cdl.ContentDocumentId);
            }
        }

        for (ContentVersion cv : cvList) {
            if (keepDocIds.contains(cv.ContentDocumentId)) {
                resp.files.add(new FileResult(cv));
            }
        }
    }
}
    @TestVisible
    private static String sanitizeForSosl(String input) {
        String result = input;
        for (String ch : new List<String>{
                '\\', '?', '&', '|', '!', '{', '}', '[', ']',
                '(', ')', '^', '~', '*', ':', '"', '\'', '+', '-'}) {
            result = result.replace(ch, '\\' + ch);
        }
        return result.trim();
    }

    public class SearchResponse {
        @AuraEnabled public List<Article>    articles = new List<Article>();
        @AuraEnabled public List<CaseResult> cases    = new List<CaseResult>();
        @AuraEnabled public List<FileResult> files    = new List<FileResult>();
    }

    public class Article {
        @AuraEnabled public String id;
        @AuraEnabled public String title;
        @AuraEnabled public String ftsTitleHtml;
        @AuraEnabled public String ftsSnippetHtml;
        @AuraEnabled public String fullUrl;
        @AuraEnabled public String projectTitle;
        @AuraEnabled public String projectId;
    }

    public class CaseResult {
        @AuraEnabled public String   id;
        @AuraEnabled public String   caseNumber;
        @AuraEnabled public String   subject;
        @AuraEnabled public String   status;
        @AuraEnabled public Datetime createdDate;
        public CaseResult(Case c) {
            this.id          = c.Id;
            this.caseNumber  = c.CaseNumber;
            this.subject     = c.Subject;
            this.status      = c.Status;
            this.createdDate = c.CreatedDate;
        }
    }

    public class FileResult {
        @AuraEnabled public String   id;
        @AuraEnabled public String   contentDocumentId;
        @AuraEnabled public String   title;
        @AuraEnabled public String   fileExtension;
        @AuraEnabled public Long     contentSize;
        @AuraEnabled public Datetime lastModifiedDate;
        public FileResult(ContentVersion cv) {
            this.id                = cv.Id;
            this.contentDocumentId = cv.ContentDocumentId;
            this.title             = cv.Title;
            this.fileExtension     = cv.FileExtension;
            this.contentSize       = cv.ContentSize;
            this.lastModifiedDate  = cv.LastModifiedDate;
        }
    }

    @AuraEnabled
    public static List<Article> searchArticles(String term) {
        if (String.isBlank(term)) return new List<Article>();
        return new ArticleFetcher().fetch(term.trim());
    }
}