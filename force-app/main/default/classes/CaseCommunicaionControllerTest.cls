@isTest
private class CaseCommunicaionControllerTest {

    @IsTest
    static void testGetFeedItems() {

        Case testCase = new Case(Status = 'New', Subject = 'Test Case');
        insert testCase;

        FeedItem feedItem = new FeedItem(
            ParentId = testCase.Id,
            Body = 'Test FeedItem Body',
            Visibility = 'AllUsers'
        );
        insert feedItem;

        ContentVersion contentVersion = new ContentVersion(
            Title = 'Test Content',
            PathOnClient = 'TestDoc.pdf',
            VersionData = Blob.valueOf('Test Content'),
            IsMajorVersion = true
        );
        insert contentVersion;

        ContentDocument contentDocument = [
            SELECT Id FROM ContentDocument WHERE LatestPublishedVersionId = :contentVersion.Id
        ];

        FeedAttachment feedAttachment = new FeedAttachment(
            FeedEntityId = feedItem.Id,
            RecordId = contentVersion.Id,
            Type = 'Content'
        );
        insert feedAttachment;

        ConnectApi.FeedElementPage testPage = new ConnectApi.FeedElementPage();
        List<ConnectApi.FeedItem> testItemList = new List<ConnectApi.FeedItem>();
        testItemList.add(new ConnectApi.FeedItem());
        testItemList.add(new ConnectApi.FeedItem());
        testPage.elements = testItemList;
        ConnectApi.ChatterFeeds.setTestGetFeedElementsFromFeed(
            null, ConnectApi.FeedType.Record, testCase.Id, testPage);

        Test.startTest();
        List<CaseCommunicationController.FeedItemWrapper> feedItemWrappers =
            CaseCommunicationController.getFeedItems(testCase.Id);
        Test.stopTest();

        System.assertNotEquals(null, feedItemWrappers);
        System.assertEquals(1, feedItemWrappers.size());
        System.assertEquals(feedItem.Id, feedItemWrappers[0].feedItem.Id);
        System.assertEquals(1, feedItemWrappers[0].contentVersions.size());
        System.assertEquals(contentVersion.Id, feedItemWrappers[0].contentVersions[0].Id);
    }

    @IsTest
    static void testCreateFeedItem() {
        Case testCase = new Case(Status = 'New', Subject = 'Test Case');
        insert testCase;

        ContentVersion contentVersion = new ContentVersion(
            Title = 'Test Content',
            PathOnClient = 'TestDoc.pdf',
            VersionData = Blob.valueOf('Test Content'),
            IsMajorVersion = true
        );
        insert contentVersion;

        List<List<String>> fileIds = new List<List<String>>();
        fileIds.add(new List<String>{ 'Test', contentVersion.Id });

        Test.startTest();
        CaseCommunicationController.isRunningTest = true;
        // CHANGED: fifth arg (inlineImages) added
        CaseCommunicationController.createFeedItem(
            '<p>Test Body</p>', testCase.Id, fileIds, null, null);
        Test.stopTest();

        List<FeedItem> feedItems = [
            SELECT Id, ParentId, Body, IsRichText FROM FeedItem WHERE ParentId = :testCase.Id
        ];
        System.assertEquals(1, feedItems.size());
        System.assert(feedItems[0].Body.contains('Test Body'),
            'Sanitized body should still contain the text');
        System.assertEquals(true, feedItems[0].IsRichText);

        List<FeedAttachment> atts = [
            SELECT Id FROM FeedAttachment WHERE FeedEntityId = :feedItems[0].Id
        ];
        System.assertEquals(1, atts.size(), 'Uploaded file should be attached');
    }

    @IsTest
    static void testCreateFeedItem_withInlineImage() {
        Case testCase = new Case(Status = 'New', Subject = 'Inline Image Case');
        insert testCase;

        // 1x1 transparent PNG
        String pngBase64 =
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

        CaseCommunicationController.InlineImage img = new CaseCommunicationController.InlineImage();
        img.base64Data = pngBase64;
        img.mimeType   = 'image/png';
        img.fileName   = 'pasted-image-1.png';

        List<CaseCommunicationController.InlineImage> images =
            new List<CaseCommunicationController.InlineImage>{ img };

        Test.startTest();
        CaseCommunicationController.isRunningTest = true;
        CaseCommunicationController.createFeedItem(
            '<p>Comment with pasted image</p>', testCase.Id, null, null, images);
        Test.stopTest();

        FeedItem fi = [SELECT Id, Body FROM FeedItem WHERE ParentId = :testCase.Id LIMIT 1];
        System.assert(fi.Body.contains('pasted image'), 'Body should persist');

        ContentVersion cv = [
            SELECT Id, Title FROM ContentVersion WHERE Title = 'pasted-image-1.png' LIMIT 1
        ];
        System.assertNotEquals(null, cv.Id, 'Base64 image should be decoded into a ContentVersion');

        List<FeedAttachment> atts = [
            SELECT Id, RecordId FROM FeedAttachment WHERE FeedEntityId = :fi.Id
        ];
        System.assertEquals(1, atts.size(), 'Decoded image should be attached to the FeedItem');
        System.assertEquals(cv.Id, atts[0].RecordId);
    }

    @IsTest
    static void testCreateFeedItem_imageOnly_noBody() {
        Case testCase = new Case(Status = 'New', Subject = 'Image Only Case');
        insert testCase;

        CaseCommunicationController.InlineImage img = new CaseCommunicationController.InlineImage();
        img.base64Data =
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';
        img.mimeType = 'image/png';
        img.fileName = 'image-only.png';

        Test.startTest();
        CaseCommunicationController.isRunningTest = true;
        // Empty body but an image present — should default Body to 'Attachment', not throw
        CaseCommunicationController.createFeedItem(
            '<p><br></p>', testCase.Id, null, null,
            new List<CaseCommunicationController.InlineImage>{ img });
        Test.stopTest();

        FeedItem fi = [SELECT Id, Body FROM FeedItem WHERE ParentId = :testCase.Id LIMIT 1];
        System.assertEquals('Attachment', fi.Body);
    }

    @IsTest
    static void testCreateFeedItem_emptyBodyNoFiles_throws() {
        Case testCase = new Case(Status = 'New', Subject = 'Empty Case');
        insert testCase;

        Boolean threw = false;
        Test.startTest();
        try {
            CaseCommunicationController.createFeedItem('<p><br></p>', testCase.Id, null, null, null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(true, threw, 'Empty body with no attachments should throw');
        System.assertEquals(0, [SELECT COUNT() FROM FeedItem WHERE ParentId = :testCase.Id]);
    }

    @IsTest
    static void testCreateFeedItem_nullParent_throws() {
        Boolean threw = false;
        Test.startTest();
        try {
            CaseCommunicationController.createFeedItem('<p>Body</p>', null, null, null, null);
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(true, threw, 'Null parentId should throw');
    }
}