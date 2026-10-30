trigger ContactTrigger on Contact (after insert, after update) {

    if (Trigger.isAfter &&  Trigger.isUpdate) {
        
       ContactTriggerHandler.updateUser(Trigger.new, Trigger.oldMap);
        
    }


}