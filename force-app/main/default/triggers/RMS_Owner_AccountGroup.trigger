trigger RMS_Owner_AccountGroup on RMS_Account_Group__c (after update) {
    Set<Id> chgOwnerAccGrps = new Set<Id>();
    
    // 修改AccountGroup的Owner时
    for (RMS_Account_Group__c accGrp: Trigger.new) {
        RMS_Account_Group__c oldAccGrp = Trigger.oldMap.get(accGrp.Id);
        
        if (accGrp.OwnerId != oldAccGrp.OwnerId) {
            chgOwnerAccGrps.add(accGrp.Id);
        }
    }
    
    // 检索AccountGroup下的SoldTo
    // 将其中未分配Owner的SoldTo分配给AccountGroup的Owner
    if (!chgOwnerAccGrps.isEmpty()) {
        List<RMS_Sold_To__c> updSoldTos = new List<RMS_Sold_To__c>();
        
        // 检索SoldTo
        for (RMS_Sold_To__c soldTo: [
            SELECT Id, Account_Group__r.OwnerId
            FROM RMS_Sold_To__c 
            WHERE Account_Group__c IN :chgOwnerAccGrps
            AND Owner.Profile.Name NOT IN ('RMS WSL Sold To', 'RMS WSL Reg Branch', 'RMS CFS Logistic Confirm', 'RMS DIG Logistic Confirm')
        ]) {
            RMS_Sold_To__c updSoldTo = new RMS_Sold_To__c();
            updSoldTo.Id = soldTo.Id;
            updSoldTo.OwnerId = soldTo.Account_Group__r.OwnerId;
            updSoldTos.add(updSoldTo);
        }
        if (!updSoldTos.isEmpty()) {
            update updSoldTos;
        }
    }
}