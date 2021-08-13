trigger RMS_Order_UnDeleted on RTV_Order__c (before delete) {
    
    Profile profile = [SELECT Name FROM Profile WHERE Id = :UserInfo.getProfileId()];
    
    for (RTV_Order__c order: Trigger.old) {
        if (!new String[]{'Ready', 'Pending'}.contains(order.Status__c)) {
            if (profile.Name != 'System Administrator') {
                order.AddError('Sorry, you can not delete order after Post LF.');
            }
        }
    }
}