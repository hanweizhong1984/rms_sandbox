// 合计 RTV_Order_Item__c 到 RTV_Order
trigger RMS_OrderItem_Total on RTV_Order_Item__c (after insert, after update, after delete) {
    // ***** 获取需要重新统计的order  *****
    set<Id> orderIds = new set<Id>();
    if(Trigger.isInsert) {
        for (RTV_Order_Item__c item: Trigger.new) {
            orderIds.add(item.RTV_Order__c);
        }
    }
    if(Trigger.isDelete) {
        for (RTV_Order_Item__c item: Trigger.old) {
            orderIds.add(item.RTV_Order__c);
        }
    }
    if(Trigger.isUpdate) {
        for (RTV_Order_Item__c item: Trigger.new) {
            RTV_Order_Item__c itemOld = Trigger.oldMap.get(item.Id);
            if (item.Application_QTY__c != itemOld.Application_QTY__c
             || item.Application_Amount__c != itemOld.Application_Amount__c
             || item.Inspect_QTY_A__c != itemOld.Inspect_QTY_A__c
             || item.Inspect_QTY_B__c != itemOld.Inspect_QTY_B__c
             || item.Inspect_QTY_C__c != itemOld.Inspect_QTY_C__c
             || item.Inspect_QTY_D__c != itemOld.Inspect_QTY_D__c
            ) {
                orderIds.add(item.RTV_Order__c);
            }
        }
    }
    
    // ***** 重新统计order  *****
    if(orderIds.size() > 0){
        Map<Id, RTV_Order__c> updOrders = new Map<Id, RTV_Order__c>();
        
        // 使用groupby合计
        for(AggregateResult inspGroup: [
                SELECT RTV_Order__c orderId,
                    SUM(Application_QTY__c) Application_QTY__c,
                    SUM(Application_Amount__c) Application_Amount__c,
                    SUM(Inspect_QTY_A__c) Inspect_QTY_A__c,
                    SUM(Inspect_QTY_B__c) Inspect_QTY_B__c,
                    SUM(Inspect_QTY_C__c) Inspect_QTY_C__c,
                    SUM(Inspect_QTY_D__c) Inspect_QTY_D__c
                FROM RTV_Order_Item__c
                WHERE RTV_Order__c IN :orderIds
                GROUP BY RTV_Order__c
            ]) {
            RTV_Order__c updO = new RTV_Order__c();
            updO.Id = (Id)inspGroup.get('orderId');
            updO.Application_QTY__c = (Double)inspGroup.get('Application_QTY__c');
            updO.Application_Amount__c = (Double)inspGroup.get('Application_Amount__c');
            updO.Inspect_QTY_A__c = (Double)inspGroup.get('Inspect_QTY_A__c');
            updO.Inspect_QTY_B__c = (Double)inspGroup.get('Inspect_QTY_B__c');
            updO.Inspect_QTY_C__c = (Double)inspGroup.get('Inspect_QTY_C__c');
            updO.Inspect_QTY_D__c = (Double)inspGroup.get('Inspect_QTY_D__c');
            updOrders.put(updO.Id, updO);
        }
        
         // 删除时，将没有item的order清空
         if (Trigger.isDelete) {
            for (RTV_Order__c updO: [
                SELECT Id FROM RTV_Order__c
                WHERE Id IN :orderIds AND Id NOT IN :updOrders.KeySet()
            ]) {
                updO.Application_QTY__c = 0;
                updO.Application_Amount__c = 0;
                updO.Inspect_QTY_A__c = 0;
                updO.Inspect_QTY_B__c = 0;
                updO.Inspect_QTY_C__c = 0;
                updO.Inspect_QTY_D__c = 0;
            }
        }
        
        // 执行order更新
        if (updOrders.size() > 0) {
            update updOrders.values();
        }
    }
}