/**
 * 1.Summary在Ready时，自动生成各个ShipTo白名单的授权码，如果没有白名单，则自动创建该AccountGroup的所有ShipTo白名单
 * 2.Summary在PostLF时，自动删除ApplicationQTY为0的Order
 */
trigger RMS_Summary_Ready_PostLF on RTV_Summary__c (after update) {
    
    //新增Order
    Set<Id> summaryId = new Set<Id>();
    Map<Id,RTV_Summary__c> summaryMap = new Map<Id,RTV_Summary__c>();
    List<RTV_RP_Ship_To__c> shipToList = new List<RTV_RP_Ship_To__c>();
    Set<ID> programList = new Set<ID>();
    //删除Order
    Set<Id> deleteSummary = new Set<Id>();
    List<RTV_Order__c> deleteOrderList = new List<RTV_Order__c>();

    Map<ID,RTV_RP_Summary_Budget__c> smBudget;

    for(RTV_Summary__c summary:Trigger.new)
    {
        //Kick Off
        RTV_Summary__c oldSummary = Trigger.oldMap.get(summary.id);
        if(summary.Status__c =='Ready' && oldSummary.Status__c =='Pending')
        {
            summaryId.add(summary.id);
            summaryMap.put(oldSummary.Account_Group__c,oldSummary);
            programList.add(oldSummary.RTV_Program__c);
        }
        //POST LF
        if(summary.Status__c =='POST to LF' && oldSummary.Status__c =='Ready')
        {
            // 非DTC时，添加到待删除订单
            if (summary.Summary_Type__c != 'DTC Takeback') {
                deleteSummary.add(summary.id);
            }
        }
    }
    // -----------------------------------------
    // Summary在Ready时，
    // 自动生成各个ShipTo白名单的授权码
    // 如果没有ShipTo白名单，则自动创建该AccountGroup的所有ShipTo白名单
    // -----------------------------------------
    if(summaryId.size()>0)
    {   
        Set<String> orderCodes = new Set<String>();
        
        //summary下white list，生成授权码
        for(RTV_RP_Ship_To__c shipTo:[
            SELECT Id,Summary__c, Order_Auth_Code__c, Removed__c,
                Summary__r.RTV_Program__r.Name,
                Summary__r.RTV_Program__r.Finance_Code__c,
                Summary__r.Account_Group__r.Name,
                Ship_To__r.id,
                Ship_To__r.Name,
                Ship_To__r.Code_Add__c,
                Sold_To__r.Id,Owner.Profile.Name
            FROM RTV_RP_Ship_To__c 
            WHERE Summary__c IN :summaryId
        ]) {
            if (shipTo.Removed__c == false) {
                // 生成随机授权码 (随机码重复时，重新随机，最多10次)
                for (Integer i=0; i<10; i++) {
                    // 生成授权码
                    shipTo.Order_Auth_Code__c = RMS_CommonUtil.order_getCode(
                        shipTo.Summary__r.RTV_Program__r.Finance_Code__c,
                        shipTo.Summary__r.Account_Group__r.Name,
                        shipTo.Ship_To__r.Name);
                    // 重复验证
                    if (orderCodes.contains(shipTo.Order_Auth_Code__c) == false) {
                        break;
                    }
                }
                orderCodes.add(shipTo.Order_Auth_Code__c);
                shipToList.add(shipTo);
            }
        }
        //white list中没有数据，生成对应Account下所有ship to的OrderCode
        if(shipToList.size()==0)
        {
            smBudget = new Map<ID,RTV_RP_Summary_Budget__c>();
            for(RTV_RP_Summary_Budget__c summary:[
                SELECT ID,
                    Account_Group__c,
                    Account_Group__r.Name,
                    Return_Program__c,
                    Return_Program__r.Name,
                    Return_Program__r.Finance_Code__c
                FROM RTV_RP_Summary_Budget__c  
                WHERE Return_Program__c IN:programList
            ]) {
                smBudget.put(summary.Account_Group__c,summary);
            }
            List<RTV_RP_Ship_To__c> rpShipToList = new List<RTV_RP_Ship_To__c>();
            for(RMS_Ship_To__c shipto:[
                SELECT ID, OwnerId, Name,
                    Sold_To_Code__c,
                    Sold_To_Code__r.Account_Group__c,
                    Sold_To_Code__r.Account_Group__r.Name 
                FROM RMS_Ship_To__c 
                WHERE Sold_To_Code__r.Account_Group__c IN: summaryMap.keySet()
            ]) {
                RTV_RP_Ship_To__c rpShipTo = new RTV_RP_Ship_To__c();
                String accountName = shipto.Sold_To_Code__r.Account_Group__r.name;
                rpShipTo.Sold_To__c = shipto.Sold_To_Code__c;
                rpShipTo.Ship_To__c = shipto.id;
                rpShipTo.RTV_Program__c = summaryMap.get(shipto.Sold_To_Code__r.Account_Group__c).RTV_Program__c;
                rpShipTo.Summary__c = summaryMap.get(shipto.Sold_To_Code__r.Account_Group__c).id;
                rpShipTo.Summary_Budget__c = smBudget.get(shipto.Sold_To_Code__r.Account_Group__c).id;
                rpShipTo.OwnerId = shipto.OwnerId;
                
                // 生成随机授权码 (随机码重复时，重新随机，最多10次)
                for (Integer i=0; i<10; i++) {
                    // 生成授权码
                    rpShipTo.Order_Auth_Code__c = RMS_CommonUtil.order_getCode(
                        smBudget.get(shipto.Sold_To_Code__r.Account_Group__c).Return_Program__r.Finance_Code__c,
                        shipto.Sold_To_Code__r.Account_Group__r.Name,
                        shipto.Name);
                    // 重复验证
                    if (orderCodes.contains(rpShipTo.Order_Auth_Code__c) == false) {
                        break;
                    }
                }
                orderCodes.add(rpShipTo.Order_Auth_Code__c);
                rpShipToList.add(rpShipTo);
            }

            insert rpShipToList;
        }
        //存在white list
        if(shipToList.size()>0)
        {
            update shipToList;
        }
    }
    // -----------------------------------------
    // Summary在PostLF时，
    // 自动删除ApplicationQTY为0的Order
    // -----------------------------------------
    if(deleteSummary.size()>0)
    {
        deleteOrderList = [SELECT Id
                           FROM RTV_Order__c 
                           WHERE 
                           Return_Summary__c IN :deleteSummary 
                           AND Application_QTY__c = 0];
        if(deleteOrderList.size()>0)
        {
            delete deleteOrderList;
        }
    }
}