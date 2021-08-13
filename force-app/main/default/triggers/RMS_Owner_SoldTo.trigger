trigger RMS_Owner_SoldTo on RMS_Sold_To__c (after update) {
    Set<Id> chgOwnerSoldToIds = new Set<Id>();
    
    // 修改SoldTo的Owner时
    for (RMS_Sold_To__c soldTo: Trigger.new) {
        RMS_Sold_To__c oldSoldto = Trigger.oldMap.get(soldTo.Id);
        
        if (soldTo.OwnerId != oldSoldTo.OwnerId) {
            chgOwnerSoldToIds.add(soldTo.Id);
        }
    }
    
    // 检索SoldTo下的ShipTo
    // 将其中未分配Owner的ShipTo分配给SoldTo的Owner
    if (!chgOwnerSoldToIds.isEmpty()) {
        List<RMS_Ship_To__c> updShipTos = new List<RMS_Ship_To__c>();
        
        // 检索ShipTo
        for (RMS_Ship_To__c shipTo: [
            SELECT Id, Sold_To_Code__r.OwnerId
            FROM RMS_Ship_To__c 
            WHERE Sold_To_Code__c IN :chgOwnerSoldToIds
            AND Owner.Profile.Name NOT IN ('RMS WSL Ship To', 'RMS WSL Ship To -Only DEF', 'RMS CFS Store', 'RMS DIG User')
        ]) {
            RMS_Ship_To__c updShipTo = new RMS_Ship_To__c();
            updShipTo.Id = shipTo.Id;
            updShipTo.OwnerId = shipTo.Sold_To_Code__r.OwnerId;
            updShipTos.add(updShipTo);
        }
        if (!updShipTos.isEmpty()) {
            update updShipTos;
        }
    }
}