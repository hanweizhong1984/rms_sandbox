/** 更新LfOrder的到货日时，更新Order和Summary的'实际到货日' */ 
trigger RMS_Order_Date_Compute on RTV_LF_Order__c (after update) {
    Map<Id, RTV_Order__c> updOrders = new Map<Id, RTV_Order__c>();
    Map<Id, RTV_Summary__c> updSummaries = new Map<Id, RTV_Summary__c>();
    
    // --------------------------
    // 更新LfOrder的到货日时
    // --------------------------
    for (RTV_LF_Order__c newLfOrd: Trigger.new) {
        RTV_LF_Order__c oldLfOrd = Trigger.oldMap.get(newLfOrd.Id);
        
        // 更新LfOrder的到货日时
        if ((newLfOrd.Delivery_Date__c != null && newLfOrd.Delivery_Date__c != oldLfOrd.Delivery_Date__c) ||
            (newLfOrd.Arrival_Date__c != null && newLfOrd.Arrival_Date__c != oldLfOrd.Arrival_Date__c)
        ) {
            // 准备更新order
            RTV_Order__c updOrd = new RTV_Order__c();
            updOrd.Id = newLfOrd.RTV_Order__c;
            updOrders.put(updOrd.Id, updOrd);
        }
    }
    
    // --------------------------
    // 合计Order的'实际到货日', 取最新日期
    // --------------------------
    if (!updOrders.isEmpty()) {
        // 合计order
        for(AggregateResult grp: [
            SELECT RTV_Order__c, 
                RTV_Order__r.Return_Summary__c Return_Summary__c,
                MAX(Delivery_Date__c) Delivery_Date__c,
                MAX(Arrival_Date__c) Arrival_Date__c
            FROM RTV_LF_Order__c
            WHERE RTV_Order__c IN :updOrders.KeySet()
            AND RTV_Order__r.Status__c IN ('POST to LF', 'Delivery', 'Inspected')
            GROUP BY RTV_Order__c, RTV_Order__r.Return_Summary__c
        ]) {
            RTV_Order__c updO = updOrders.get((Id)grp.get('RTV_Order__c'));
            updO.Actual_Date_Of_Delivered__c = (Date)grp.get('Delivery_Date__c');
            updO.Actual_Date_Of_Delivered_Complete__c = (Date)grp.get('Arrival_Date__c');
            
            // 获取待更新summary
            if ((Id)grp.get('Return_Summary__c') != null) {
                RTV_Summary__c updSum = new RTV_Summary__c();
                updSum.Id = (Id)grp.get('Return_Summary__c');
                updSummaries.put(updSum.Id, updSum);
            }
        }
        update updOrders.values();
    }
    
    // --------------------------
    // 合计Summary的'实际到货日', 取最新日期
    // --------------------------
    if (!updSummaries.isEmpty()) {
        for(AggregateResult grp: [
            SELECT Return_Summary__c,
                MAX(Actual_Date_Of_Delivered__c) Actual_Date_Of_Delivered__c,
                MAX(Actual_Date_Of_Delivered_Complete__c) Actual_Date_Of_Delivered_Complete__c
            FROM RTV_Order__c
            WHERE Return_Summary__c IN :updSummaries.KeySet()
            GROUP BY Return_Summary__c
        ]) {
            RTV_Summary__c updSum = updSummaries.get((Id)grp.get('Return_Summary__c'));
            updSum.Actual_Date_Of_Delivered__c = (Date)grp.get('Actual_Date_Of_Delivered__c');
            updSum.Actual_Date_Of_Delivered_Complete__c = (Date)grp.get('Actual_Date_Of_Delivered_Complete__c');
        }
        update updSummaries.values();
    }
    
    // String delId = null;
    // // String delOrderId = null;
    // Set<Id> orderSet = new Set<Id>();

    // List<RTV_Order__c> updateOrder = new List<RTV_Order__c>();
    // if(Trigger.isUpdate)
    // {
    //     if(Trigger.isAfter)
    //     {
    //         for(RTV_Order__c newOrder:Trigger.new)
    //         {
    //             RTV_Order__c oldOrder = Trigger.oldMap.get(newOrder.id);

    //             //当LF上传Deliver后，更新Summary的LF提货运输完成实际日期
    //             if(newOrder.Status__c == 'Delivered' && oldOrder.Status__c == 'POST to LF')
    //             {
    //                 delId = newOrder.Return_Summary__c;
    //                 // delOrderId = newOrder.id;
    //                 orderSet.add(newOrder.id);
    //             }

    //         }  
    //     }   
    // }
    // //--------------------
    // //当order状态POST to LF → Delivered ,更新Order
    // //--------------------
    // if(orderSet.size()>0)
    // {
    //     List<AggregateResult> delDateList = [SELECT RTV_Order__r.id rtvId,	
    //                                             MAX(Delivery_Date__c) Delivery_Date__c,
    //                                             MAX(Arrival_Date__c)  Arrival_Date__c
    //                                             FROM RTV_LF_Order__c 
    //                                             WHERE RTV_Order__c IN :orderSet
    //                                             GROUP BY RTV_Order__r.id];
    //     for(AggregateResult delDate :delDateList)
    //     {
    //         RTV_Order__c order = new RTV_Order__c();
    //         order.id = (ID)delDate.get('rtvId');
    //         order.Actual_Date_Of_Delivered__c = (Date)delDate.get('Delivery_Date__c');
    //         order.Actual_Date_Of_Delivered_Complete__c = (Date)delDate.get('Arrival_Date__c');
    //         updateOrder.add(order);
    //     }
    //     update updateOrder;
    // }
    // //--------------------
    // //当order状态POST to LF → Delivered ,更新Summary
    // //--------------------
    // if(delId != null)
    // {
    //     //查找当前order对应summary下，POST to LF状态的Order
    //     List<RTV_Order__c> delOrder = [SELECT 
    //                                     id 
    //                                     FROM RTV_Order__c
    //                                     WHERE Return_Summary__c = :delId 
    //                                     AND Status__c='POST to LF'];
    //     //summary下所有Order转为deliver状态，更新summary
    //     if(delOrder.size() == 0)
    //     {
    //         //获取最晚时间
    //         AggregateResult delDate = [SELECT 	
    //                                     MAX(Delivery_Date__c) Delivery_Date__c ,
    //                                     MAX(Arrival_Date__c)  Arrival_Date__c
    //                                     FROM RTV_LF_Order__c 
    //                                     WHERE RTV_Order__r.Return_Summary__c = :delId];
    //         RTV_Summary__c summary = new RTV_Summary__c();
    //         summary.id = delId;
    //         summary.Actual_Date_Of_Delivered__c = (Date)delDate.get('Delivery_Date__c');
    //         summary.Actual_Date_Of_Delivered_Complete__c = (Date)delDate.get('Arrival_Date__c');
    //         update summary;
    //     }
    // }
}