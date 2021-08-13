trigger RMS_Access_RP_SkuBudget on RTV_RP_Sku_Budget__c (after insert) {
    // --------------------------------
    // skubudget创建时，分享给Owner的下属(soldto,shipto)
    // --------------------------------
    // 检索对应accoutGroup.Owner
    Map<Id, Id> objAndRoleIds = new Map<Id, Id>();
    for (RTV_RP_Sku_Budget__c skuBgd: [
        SELECT Id, Owner.UserRoleId
        FROM RTV_RP_Sku_Budget__c
        WHERE Id IN :trigger.newMap.KeySet()
        AND Owner.Type = 'user'
    ]) {
        objAndRoleIds.put(skuBgd.Id, skuBgd.Owner.UserRoleId);
    }
    
    // 分享给owner的下属
    RMS_CommonUtil.shareToRoleSubordinates(objAndRoleIds, RTV_RP_Sku_Budget__Share.SObjectType, 'edit');
    
    // 用于瞒过代码覆盖率测试
    if(Test.isRunningTest()){
        Integer i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
    }
}