/**
 * 当order从Ready变为PostLF时:根据BU创建lfOrder对象
 */
trigger RMS_Order_PostLF on RTV_Order__c (before update,after update) {
    Set<Id> chgOrderIds = new Set<Id>();

    Map<String,RTV_Order__c> orderMap = new Map<String,RTV_Order__c> ();
    Map<String, RecordType> allTypes;

    //更新前
    if(Trigger.isBefore)
    {
        for (RTV_Order__c newOrd: Trigger.new) {
            RTV_Order__c oldOrd = Trigger.oldMap.get(newOrd.Id);

            if (oldOrd.OrderPTLF__c == false && newOrd.OrderPTLF__c == true 
                && oldOrd.Status__c == 'Ready'
                && oldOrd.Return_Summary__c != null) {
                
                    orderMap.put(newOrd.id,newOrd);
            }
            if (newOrd.Status__c == 'Ready'
                && oldOrd.Return_Summary__c != null) {
                
                    newOrd.OrderPTLF__c = false;
            }
        }

    }
    //YY客户可以以Order为单位POST TO LF
    if(orderMap.size()>0)
    {
        if (allTypes == null) {
            allTypes = RMS_CommonUtil.getRecordTypes('RTV_Order__c');
        }
        for(RTV_Order__c order:[SELECT ID,Return_Summary__r.Account_Group__r.name, IsDTC__c 
                                FROM RTV_Order__c WHERE ID IN :orderMap.keySet()])
        {
            // WSL中，只有'YY' 和'BELLE' 和'BJKT' 和'BaoShang'允许单独PostLF
            if(order.Return_Summary__r.Account_Group__r.name == '01)YY'|| order.Return_Summary__r.Account_Group__r.name == '02)BELLE'
                 || order.Return_Summary__r.Account_Group__r.name == '03)BJKT' || order.Return_Summary__r.Account_Group__r.name == '06)Baoshang')
            {
                orderMap.get(order.ID).Status__c = 'POST to LF';
                orderMap.get(order.ID).RecordTypeId = allTypes.get('WSL Takeback Post LF').id;
            }
            // DTC允许单独PostLF
            else if(order.IsDTC__c)
            {
                orderMap.get(order.ID).Status__c = 'POST to LF';
                orderMap.get(order.ID).RecordTypeId = allTypes.get('DTC Takeback Post LF').id;
            }
            else {
                orderMap.get(order.ID).addError('POST to LF can be summited only once!');
            }
        }
    }
    
    // 当order从Ready变为PostLF时
    if(Trigger.isAfter)
    {
        for (RTV_Order__c newOrd: Trigger.new) {
            RTV_Order__c oldOrd = Trigger.oldMap.get(newOrd.Id);
            if (oldOrd.Status__c == 'Ready' && newOrd.Status__c == 'POST to LF' && newOrd.Application_QTY__c != 0) {
                chgOrderIds.add(newOrd.Id);
            }
        }
    }
    

    // 根据BU创建个lfOrder对象
    if (!chgOrderIds.isEmpty()) {
        // 待创建的提货单
        List<RTV_LF_Order__c> upsertLfOrders = new List<RTV_LF_Order__c>();
        // 不创建提货单，直接完成运输的OrderId
        Set<Id> autoDeliveryOrderIds = chgOrderIds;
        
        // 检索现有的lfOrder
        Map<String, Id> extLfOrders = new Map<String, Id>();
        for (RTV_LF_Order__c lfO: [SELECT Id, LF_Order_Auth_Code__c FROM RTV_LF_Order__c WHERE RTV_Order__c IN :chgOrderIds]) {
            extLfOrders.put(lfO.LF_Order_Auth_Code__c, lfO.Id);
        }
        
        // 检索'POST to LF'的order中
        for (AggregateResult grp: [
            SELECT BU_2__c, 
                RTV_Order__c,
                RTV_Order__r.Name OrderCode,
                AVG(RTV_Order__r.AC_Boxes__c) AC_Boxes__c,
                AVG(RTV_Order__r.AP_Boxes__c) AP_Boxes__c,
                AVG(RTV_Order__r.FW_Boxes__c) FW_Boxes__c,
                SUM(Application_QTY__c) Application_QTY__c
            FROM RTV_Order_Item__c
            WHERE RTV_Order__c IN :chgOrderIds AND 	IsMaterial__c = false
            GROUP BY BU_2__c, RTV_Order__c, RTV_Order__r.Name
        ]) {
            // lfOrder的code为 order.name + BU
            String lfOrderCode = (String)grp.get('OrderCode') + (String)grp.get('BU_2__c');
            
            // lforder信息
            RTV_LF_Order__c lfOrder = new RTV_LF_Order__c();
            lfOrder.Name = lfOrderCode;
            lfOrder.LF_Order_Auth_Code__c = lfOrderCode;
            lfOrder.BU_2__c = (String)grp.get('BU_2__c');
            lfOrder.RTV_Order__c = (Id)grp.get('RTV_Order__c');
            lfOrder.Application_QTY__c = (Decimal)grp.get('Application_QTY__c');
            
            lfOrder.Application_Box_QTY__c = 
                lfOrder.BU_2__c == 'AC'? (Decimal)grp.get('AC_Boxes__c'):
                lfOrder.BU_2__c == 'AP'? (Decimal)grp.get('AP_Boxes__c'):
                lfOrder.BU_2__c == 'FW'? (Decimal)grp.get('FW_Boxes__c'): 0;
                
            // 该lforder已经存在时
            lfOrder.Id = extLfOrders.get(lfOrderCode);
            
            upsertLfOrders.add(lfOrder);
            autoDeliveryOrderIds.remove(lfOrder.RTV_Order__c);
        }
        
        // 创建LfOrder
        if (!upsertLfOrders.isEmpty()) {
            upsert upsertLfOrders;
        }
        // 不创建提货单，直接完成运输的OrderId
        if (!autoDeliveryOrderIds.isEmpty()) {
            List<RTV_Order__c> autoDeliveryOrders = new List<RTV_Order__c>();
            
            for (Id orderId: autoDeliveryOrderIds) {
                RTV_Order__c dlyOrder = new RTV_Order__c();
                dlyOrder.Id = orderId;
                dlyOrder.Status__c = 'Delivered';
                autoDeliveryOrders.add(dlyOrder);
            }
            update autoDeliveryOrders;
        }
    }
}