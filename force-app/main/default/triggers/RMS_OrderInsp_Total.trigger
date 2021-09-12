// 合计 RTV_Order_Inspection__c 到 RTV_Order_Item__c
trigger RMS_OrderInsp_Total on RTV_Order_Inspection__c (after insert, after update, after delete) {

    List<RTV_Order_Item__c> itemList = new List<RTV_Order_Item__c>();
    if(Trigger.isInsert) {
        for (RTV_Order_Inspection__c insp: Trigger.new) {
            RTV_Order_Item__c item = new RTV_Order_Item__c();
            item.Id = insp.RTV_Order_Item__c;
            item.Inspect_QTY_A__c = insp.A__c;
            item.Inspect_QTY_B__c = insp.B__c;
            item.Inspect_QTY_C__c = insp.C__c;
            item.Inspect_QTY_D__c = insp.D__c;
            item.Insp_Actual_QTY__c = insp.Delivery_QTY__c;
            itemList.add(item);
        }
    }
    if(Trigger.isDelete) {
        for (RTV_Order_Inspection__c inspOld: Trigger.old) {
            RTV_Order_Item__c item = new RTV_Order_Item__c();
            item.Id = inspOld.RTV_Order_Item__c;
            item.Inspect_QTY_A__c = 0;
            item.Inspect_QTY_B__c = 0;
            item.Inspect_QTY_C__c = 0;
            item.Inspect_QTY_D__c = 0;
            itemList.add(item);
        }
    }
    if(Trigger.isUpdate) {
        for (RTV_Order_Inspection__c insp: Trigger.new) {
            RTV_Order_Inspection__c inspOld = Trigger.oldMap.get(insp.Id);
            if (insp.A__c != inspOld.A__c
             || insp.B__c != inspOld.B__c
             || insp.C__c != inspOld.C__c
             || insp.D__c != inspOld.D__c
             || insp.Delivery_QTY__c != inspOld.Delivery_QTY__c) {
                RTV_Order_Item__c item = new RTV_Order_Item__c();
                item.Id = insp.RTV_Order_Item__c;
                item.Inspect_QTY_A__c = insp.A__c;
                item.Inspect_QTY_B__c = insp.B__c;
                item.Inspect_QTY_C__c = insp.C__c;
                item.Inspect_QTY_D__c = insp.D__c;
                item.Insp_Actual_QTY__c = insp.Delivery_QTY__c;
                itemList.add(item);
            }
        }
    }
    
    // 重新统计order
    if(itemList.size() > 0){
        update itemList;
    }
}