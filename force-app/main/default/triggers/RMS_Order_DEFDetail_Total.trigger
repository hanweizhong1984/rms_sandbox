trigger RMS_Order_DEFDetail_Total on RTV_Order_Item_DEF_Detail__c (after update) {
    List<RTV_Order_Item_DEF_Detail__c> workingItems = Trigger.isDelete? trigger.old: trigger.new;
    
    // 待更新的item
    Map<Id, RTV_Order_Item__c> updItems = new Map<Id, RTV_Order_Item__c>();
    
    // --------------------------
    // 遍历数量变更的defDetail
    // --------------------------
    for (RTV_Order_Item_DEF_Detail__c detail: workingItems) {
        RTV_Order_Item_DEF_Detail__c oldDetail = Trigger.isUpdate? trigger.oldMap.get(detail.Id): null;
        
        // 或者更新: 接收数量，拒绝数量 时
        if (Trigger.isUpdate
            || detail.Acceptable_Return_QTY__c != oldDetail.Acceptable_Return_QTY__c
            || detail.Reject_QTY__c != oldDetail.Reject_QTY__c
        ) {
            // 准备更新关联的SkuBudget
            RTV_Order_Item__c item = new RTV_Order_Item__c();
            item.Id = detail.RTV_Order_Item__c;
            item.Inspect_QTY_D__c = 0;
            item.Inspect_QTY_C__c = 0;
            updItems.put(item.Id, item);
        }
    }
    // --------------------------
    // 重新统计item的inspectQty(C,D)
    // --------------------------
    if (!updItems.isEmpty()) {
        // 检索目标SkuBudget以及其下的item合计
        for (AggregateResult grp: [
            SELECT RTV_Order_Item__c, 
                SUM(Acceptable_Return_QTY__c) sumAcceptQty,
                SUM(Reject_QTY__c) sumRejectQTY
            FROM RTV_Order_Item_DEF_Detail__c
            WHERE RTV_Order_Item__c IN :updItems.KeySet()
            GROUP BY RTV_Order_Item__c
        ]) {
            // 更新item
            RTV_Order_Item__c updItem = updItems.get((Id)grp.get('RTV_Order_Item__c'));
            updItem.Inspect_QTY_D__c = (Decimal)grp.get('sumAcceptQty');
            updItem.Inspect_QTY_C__c = (Decimal)grp.get('sumRejectQTY');
        }
        // 更新
        update updItems.values();
    }
    
    // List<RTV_Order_Item__c> itemList = new List<RTV_Order_Item__c>();
    // Set<Id> itemID = new Set<Id>();
    // if(Trigger.isInsert) {
    //     for (RTV_Order_Item_DEF_Detail__c detail: Trigger.new) {
    //         itemID.add(detail.RTV_Order_Item__c);
    //     }
    // }
    // if(Trigger.isUpdate) {
    //     for (RTV_Order_Item_DEF_Detail__c detail: Trigger.new) {
    //         RTV_Order_Item_DEF_Detail__c oldDetail = Trigger.oldMap.get(detail.Id);
    //         if (detail.Actual_QTY__c != oldDetail.Actual_QTY__c) {
    //             itemID.add(detail.RTV_Order_Item__c);
    //         }
    //     }
    // }
    // if(Trigger.isDelete) {
    //     for (RTV_Order_Item_DEF_Detail__c detail: Trigger.old) {
    //         itemID.add(detail.RTV_Order_Item__c);
    //     }
    // }
    
    // if(itemID.size() > 0){
    //     Map<String,List<Decimal>> qtyMap = new Map<String,List<Decimal>>();
        
    //     for(RTV_Order_Item_DEF_Detail__c detail:[SELECT Actual_QTY__c,RTV_Order_Item__c FROM RTV_Order_Item_DEF_Detail__c where RTV_Order_Item__c IN:itemID])
    //     {
    //         List<Decimal> qtyList = new List<Decimal>();
     
    //         if(qtyMap.containsKey(detail.RTV_Order_Item__c))
    //         {
    //             qtyMap.get(detail.RTV_Order_Item__c).add(detail.Actual_QTY__c);
    //         }
    //         else {
    //             qtyList.add(detail.Actual_QTY__c);
    //             qtyMap.put(detail.RTV_Order_Item__c,qtyList);
    //         }
    //     }
    //     for(String ID:qtyMap.keySet())
    //     {
    //         RTV_Order_Item__c item = new RTV_Order_Item__c();
    //         item.id = ID;
    //         Decimal sum = 0;
    //         for(Decimal qty:qtyMap.get(item.id))
    //         {
    //             if(qty==null)
    //             {
    //                 qty =0;
    //             }
    //             sum = sum+qty;
    //         }
    //         item.Inspect_QTY_D__c = sum;
    //         itemList.add(item);
    //     }
        
    //     update itemList;
    // }
}