// 合计 RTV_LF_Order__c 到 RTV_Order
trigger RMS_OrderLF_Total on RTV_LF_Order__c (after update) {
    // ***** 获取需要重新统计的order  *****
    set<Id> orderIds = new set<Id>();
    
    // if(Trigger.isInsert) {
    //     for (RTV_LF_Order__c lfOrder: Trigger.new) {
    //         if (lfOrder.Delivery_QTY__c != 0 && lfOrder.Delivery_QTY__c != null) {
    //             orderIds.add(lfOrder.RTV_Order__c);
    //         }
    //     }
    // }
    // if(Trigger.isDelete) {
    //     for (RTV_LF_Order__c lfOrder: Trigger.old) {
    //         if (lfOrder.Delivery_QTY__c != 0 && lfOrder.Delivery_QTY__c != null) {
    //             orderIds.add(lfOrder.RTV_Order__c);
    //         }
    //     }
    // }
    if(Trigger.isUpdate) {
        for (RTV_LF_Order__c lfOrder: Trigger.new) {
            RTV_LF_Order__c lfOrderOld = Trigger.oldMap.get(lfOrder.Id);
            if (lfOrder.Delivery_QTY__c != lfOrderOld.Delivery_QTY__c) {
                orderIds.add(lfOrder.RTV_Order__c);
            }
        }
    }
    
    // ***** 重新统计order  *****
    if(orderIds.size() > 0){
        Map<Id, RTV_Order__c> updOrders = new Map<Id, RTV_Order__c>();
        
        // 使用groupby合计
        for(AggregateResult inspGroup: [
                SELECT RTV_Order__c orderId,
                    SUM(Delivery_QTY__c) Delivery_QTY__c
                FROM RTV_LF_Order__c
                WHERE RTV_Order__c IN :orderIds
                GROUP BY RTV_Order__c
            ]) {
            RTV_Order__c updO = new RTV_Order__c();
            updO.Id = (Id)inspGroup.get('orderId');
            updO.Delivery_QTY__c = (Double)inspGroup.get('Delivery_QTY__c');
            updOrders.put(updO.Id, updO);
        }
        
         // 删除时，将没有item的order清空
         if (Trigger.isDelete) {
            for (RTV_Order__c updO: [
                SELECT Id FROM RTV_Order__c
                WHERE Id IN :orderIds AND Id NOT IN :updOrders.KeySet()
            ]) {
                updO.Delivery_QTY__c = 0;
            }
        }
        
        // 执行order更新
        if (updOrders.size() > 0) {
            update updOrders.values();
        }
    }
}