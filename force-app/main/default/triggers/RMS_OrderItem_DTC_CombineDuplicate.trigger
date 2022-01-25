trigger RMS_OrderItem_DTC_CombineDuplicate on RTV_Order_Item__c (after insert) {
    set<Id> orderIds = new set<Id>();
    //先过滤出是DTC的OrderItem
    for (RTV_Order_Item__c item: Trigger.new) {
        if(item.IsDTC__c ==true && item.RTV_DEF_Summary__c == null){
            orderIds.add(item.RTV_Order__c);
         }
    }

    //分组合计出以POS SKU分组的Application QTY
    Map<String,Long> grpMap = new Map<String,Long>();
    for (AggregateResult grp: [
        SELECT 
        RTV_Order__r.Name orderName,
        POS_SKU__c,
        SUM(Application_QTY__c) qty
        FROM RTV_Order_Item__c 
        WHERE RTV_Order__c 
        IN :orderIds 
        GROUP BY POS_SKU__c,RTV_Order__r.Name
        ]) {
            Long applicationQty = ((Decimal)grp.get('qty')).round();
            String sku = (String)grp.get('POS_SKU__c');
            String orderName = (String)grp.get('orderName');
            grpMap.put(orderName+sku,applicationQty);
        }
    
    //查出重复记录
    set<string> duplicateCheck = new Set<string>();
    set<Id> dupIds = new Set<Id>();
    for(RTV_Order_Item__c item : [SELECT Id, Name,RTV_Order__c, Application_QTY__c,POS_SKU__c FROM RTV_Order_Item__c WHERE RTV_Order__c IN :orderIds]){
        if(!duplicateCheck.add(item.RTV_Order__c+item.POS_SKU__c)){
            dupIds.add(item.Id);
        }
    }
    system.debug('dupIds'+dupIds);
    
    //删除重复记录
    delete [SELECT Id from RTV_Order_Item__c where Id IN :dupIds];

     //更新保留记录的Application QTY
     List<RTV_Order_Item__c> upItemList = new List<RTV_Order_Item__c>();
     for(RTV_Order_Item__c item : [SELECT Id, Name,RTV_Order__r.Name, Application_QTY__c,POS_SKU__c FROM RTV_Order_Item__c WHERE RTV_Order__c IN :orderIds]){
        RTV_Order_Item__c obj = new RTV_Order_Item__c();
        obj.Id = item.Id;
        obj.Application_QTY__c = grpMap.get(item.RTV_Order__r.Name+item.POS_SKU__c);
        upItemList.add(obj);
     }

     update upItemList;

}