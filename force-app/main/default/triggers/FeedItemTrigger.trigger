trigger FeedItemTrigger on FeedItem (After insert) {
    List<FeedItem__e> events = new List<FeedItem__e>();
    if (Trigger.isAfter && Trigger.isInsert) {
        system.debug('====> inside the trigger');
        CaseCommunicationController.notifyUsers(Trigger.new);
    }
}