trigger RMS_Access_DEF_Summary on RTV_DEF_Summary__c (after insert, after update) {
    
    // active变为opening的defsummary
    Set<Id> openDefSumIds = new Set<Id>();
    
    // 遍历defsummary
    for (RTV_DEF_Summary__c newDefSum: Trigger.new) {
        RTV_DEF_Summary__c oldDefSum = Trigger.isUpdate? trigger.oldMap.get(newDefSum.Id): null;
        
        // active -> opening 时, 并且是WSL的DEF Summary时
        if (Trigger.isInsert || (Trigger.isUpdate && oldDefSum.Active_Status__c != newDefSum.Active_Status__c)) {
            if (newDefSum.Active_Status__c == 'Opening' && newDefSum.DTC_Type__c == null) {
                openDefSumIds.add(newDefSum.Id);
            }
        }
    }
    
    // --------------------------------------
    // 当defsummary在open时，
    // 1.将owner转交给"WSL HQ"，
    // 2.分享该"WSL HQ"的下属
    // --------------------------------------
    if (!openDefSumIds.isEmpty()) {
        
        Map<Id, Id> objAndOwnerRoleIds = new Map<Id, Id>();
        List<RTV_DEF_Summary__c> updDefSummary = new List<RTV_DEF_Summary__c>();
        
        // 检索更新的defsummary
        for (RTV_DEF_Summary__c defSum: [
            SELECT Id, Account_Group__r.OwnerId, 
                Account_Group__r.Owner.UserRoleId,
                Account_Group__r.Owner.Type
            FROM RTV_DEF_Summary__c
            WHERE Id IN :openDefSumIds
            AND Account_Group__r.OwnerId != null
        ]) {
            // 修改Owner为AccountGroup的Owner
            RTV_DEF_Summary__c updDefS = new RTV_DEF_Summary__c();
            updDefS.Id = defSum.Id;
            updDefS.OwnerId = defSum.Account_Group__r.OwnerId;
            updDefSummary.add(updDefS);
            
            // 共享给owner的下属
            if (defSum.Account_Group__r.Owner.Type == 'user') {
                objAndOwnerRoleIds.put(defSum.Id, defSum.Account_Group__r.Owner.UserRoleId);
            }
        }
        // 更新summary
        update updDefSummary;
        // 分享给owner的下属
        RMS_CommonUtil.shareToRoleSubordinates(objAndOwnerRoleIds, RTV_DEF_Summary__Share.SObjectType, 'edit');
    }
}