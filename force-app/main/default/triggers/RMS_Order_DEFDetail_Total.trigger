trigger RMS_Order_DEFDetail_Total on RTV_Order_Item_DEF_Detail__c (after insert,after update) {
    List<RTV_Order_Item_DEF_Detail__c> workingItems = Trigger.isDelete? trigger.old: trigger.new;
    
    // 待更新的item
    Map<Id, RTV_Order_Item__c> updItems = new Map<Id, RTV_Order_Item__c>();
    
    // --------------------------
    // 遍历数量变更的defDetail
    // --------------------------
    for (RTV_Order_Item_DEF_Detail__c detail: workingItems) {
        RTV_Order_Item_DEF_Detail__c oldDetail = Trigger.isUpdate? trigger.oldMap.get(detail.Id): null;
        
        // 或者更新: 接收数量，拒绝数量 时
        if (Trigger.isInsert||(Trigger.isUpdate
            || detail.Acceptable_Return_QTY__c != oldDetail.Acceptable_Return_QTY__c
            || detail.Reject_QTY__c != oldDetail.Reject_QTY__c
        )) {
            // 准备更新关联的SkuBudget
            RTV_Order_Item__c item = new RTV_Order_Item__c();
            item.Id = detail.RTV_Order_Item__c;
            item.Inspect_QTY_D__c = 0;
            item.Inspect_QTY_C__c = 0;
            updItems.put(item.Id, item);
        }
    }
    System.debug('updItems.KeySet():'+updItems.KeySet());
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
            Decimal sumAcceptQty = (Decimal)grp.get('sumAcceptQty')!=null?(Decimal)grp.get('sumAcceptQty'):0;
            Decimal sumRejectQTY = (Decimal)grp.get('sumRejectQTY')!=null?(Decimal)grp.get('sumRejectQTY'):0;
            // 更新item
            RTV_Order_Item__c updItem = updItems.get((Id)grp.get('RTV_Order_Item__c'));
            updItem.Inspect_QTY_D__c = sumAcceptQty;
            updItem.Inspect_QTY_C__c = sumRejectQTY;
        }
        // 更新
        update updItems.values();
    }
}