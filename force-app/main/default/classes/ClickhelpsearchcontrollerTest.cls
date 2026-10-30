@isTest
private class ClickhelpsearchcontrollerTest {

    private class ClickHelpMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            System.assert(req.getEndpoint().contains('/api/v1/search'),
                'Should hit the ClickHelp search resource');
            System.assert(req.getEndpoint().contains('isReturnSnippets=1'),
                'Should request highlighted snippets');
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody(
                '[{' +
                '"id":"test-assembling",' +
                '"title":"Test Assembling",' +
                '"ftsTitleHtml":"<strong>Test</strong> Assembling",' +
                '"ftsSnippetHtml":"...you can <strong>test</strong> assemble a document...",' +
                '"fullUrl":"https://docs.ghostdraft.com/articles/studio/test-assembling",' +
                '"projectId":"studio",' +
                '"projectTitle":"Studio",' +
                '"indexKeywords":[],' +
                '"createdOn":"2026-06-10T14:50:37"' +
                '}]'
            );
            return res;
        }
    }

    private class ClickHelpErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(401);
            res.setBody('Unauthorized');
            return res;
        }
    }

    @testSetup
    static void makeData() {
        // CHANGED: Origin must be 'Web' or CaseSearcher filters it out
        insert new Case(
            Subject = 'Studio: test assembling issue',
            Status  = 'New',
            Origin  = 'Web'
        );

        ContentVersion cv = new ContentVersion(
            Title        = 'GhostDraft Studio Orientation Tour',
            PathOnClient = 'tour.pdf',
            VersionData  = Blob.valueOf('dummy-bytes')
        );
        insert cv;
    }

    @isTest
    static void search_returnsArticlesAndCases() {
        Case c = [SELECT Id, CaseNumber, Subject, Status, CreatedDate FROM Case LIMIT 1];
        ContentVersion cv = [
            SELECT Id, ContentDocumentId FROM ContentVersion WHERE IsLatest = true LIMIT 1
        ];

        Test.setMock(HttpCalloutMock.class, new ClickHelpMock());
        Test.setFixedSearchResults(new List<Id>{ c.Id, cv.Id });

        Test.startTest();
        Clickhelpsearchcontroller.SearchResponse resp =
            Clickhelpsearchcontroller.search('test assembling');
        Test.stopTest();

        // Articles
        System.assertEquals(1, resp.articles.size(), 'One ClickHelp article expected');
        System.assertEquals('Studio', resp.articles[0].projectTitle);
        System.assertEquals(
            'https://docs.ghostdraft.com/articles/studio/test-assembling',
            resp.articles[0].fullUrl
        );

        // Cases — this is what exercises the CaseResult constructor
        System.assertEquals(1, resp.cases.size(), 'One Case expected');
        Clickhelpsearchcontroller.CaseResult cr = resp.cases[0];
        System.assertEquals(c.Id,          cr.id);
        System.assertEquals(c.CaseNumber,  cr.caseNumber);
        System.assertEquals(c.Subject,     cr.subject);
        System.assertEquals(c.Status,      cr.status);
        System.assertEquals(c.CreatedDate, cr.createdDate);
    }

    @isTest
    static void search_blankTerm_returnsEmpty() {
        Test.startTest();
        Clickhelpsearchcontroller.SearchResponse resp =
            Clickhelpsearchcontroller.search('   ');
        Test.stopTest();

        System.assertEquals(0, resp.articles.size());
        System.assertEquals(0, resp.cases.size());
        System.assertEquals(0, resp.files.size());
    }

    @isTest
    static void search_clickHelpError_doesNotThrow() {
        Test.setMock(HttpCalloutMock.class, new ClickHelpErrorMock());
        Test.setFixedSearchResults(new List<Id>());

        Test.startTest();
        Clickhelpsearchcontroller.SearchResponse resp =
            Clickhelpsearchcontroller.search('anything');
        Test.stopTest();

        System.assertEquals(0, resp.articles.size(),
            'A 401 should yield no articles and no exception');
    }

    @isTest
    static void search_nonWebCase_isExcluded() {
        Case emailCase = new Case(
            Subject = 'Studio: test assembling issue via email',
            Status  = 'New',
            Origin  = 'Email'
        );
        insert emailCase;

        Test.setMock(HttpCalloutMock.class, new ClickHelpMock());
        Test.setFixedSearchResults(new List<Id>{ emailCase.Id });

        Test.startTest();
        Clickhelpsearchcontroller.SearchResponse resp =
            Clickhelpsearchcontroller.search('test assembling');
        Test.stopTest();

        System.assertEquals(0, resp.cases.size(),
            'Non-Web cases must not surface in site search');
    }

    @isTest
    static void searchArticles_returnsArticles() {
        Test.setMock(HttpCalloutMock.class, new ClickHelpMock());

        Test.startTest();
        List<Clickhelpsearchcontroller.Article> articles =
            Clickhelpsearchcontroller.searchArticles('test');
        Test.stopTest();

        System.assertEquals(1, articles.size());
        System.assertEquals('Studio', articles[0].projectTitle);
    }

    @isTest
    static void searchArticles_blankTerm_returnsEmpty() {
        Test.startTest();
        List<Clickhelpsearchcontroller.Article> articles =
            Clickhelpsearchcontroller.searchArticles('  ');
        Test.stopTest();

        System.assertEquals(0, articles.size());
    }

    @isTest
    static void sanitizeForSosl_escapesReservedChars() {
        String out = Clickhelpsearchcontroller.sanitizeForSosl('a+b:c?');
        System.assert(
            out.contains('\\+') && out.contains('\\:') && out.contains('\\?'),
            'Reserved SOSL characters should be backslash-escaped'
        );
    }
}