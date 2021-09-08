trigger RMS_OrderItem_Size_DTC on RTV_Order_Item__c (before insert) {
    for (RTV_Order_Item__c item: Trigger.new) {
        if (item.IsDTC__c == true){
            if(item.SKU_Size_Asia__c != null) {
                item.SKU_Size_US__c = RMS_CommonUtil.size_Asia2Us(item.SKU_Size_Asia__c,item.BU_2__c);
            }
        }
    }
}