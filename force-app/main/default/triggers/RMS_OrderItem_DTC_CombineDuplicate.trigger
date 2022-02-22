trigger RMS_OrderItem_DTC_CombineDuplicate on RTV_Order_Item__c (after insert) {
    set<Id> orderIds = new set<Id>();
    //先过滤出是DTC的OrderItem
    for (RTV_Order_Item__c item: Trigger.new) {
        if(item.IsDTC__c ==true && item.RTV_DEF_Summary__c == null){
            orderIds.add(item.RTV_Order__c);
         }
    }

    //分组合计出以POS SKU分组的Application QTY
    // Map<String,Long> grpMap = new Map<String,Long>();
    // for (AggregateResult grp: [
    //     SELECT 
    //     RTV_Order__r.Name orderName,
    //     POS_SKU__c,
    //     SUM(Application_QTY__c) qty
    //     FROM RTV_Order_Item__c 
    //     WHERE RTV_Order__c 
    //     IN :orderIds 
    //     GROUP BY POS_SKU__c,RTV_Order__r.Name
    //     ]) {
    //         Long applicationQty = ((Decimal)grp.get('qty')).round();
    //         String sku = (String)grp.get('POS_SKU__c');
    //         String orderName = (String)grp.get('orderName');
    //         grpMap.put(orderName+sku,applicationQty);
    //     }
    
    Map<String,List<Integer>> qtyMap = new Map<String,List<Integer>>();    
    //查出重复记录
    set<string> duplicateCheck = new Set<string>();
    set<Id> dupIds = new Set<Id>();
    String key;
    for(RTV_Order_Item__c item : [SELECT Id, Name,RTV_Order__c, Application_QTY__c,POS_SKU__c FROM RTV_Order_Item__c WHERE RTV_Order__c IN :orderIds]){
        key = item.RTV_Order__c + item.POS_SKU__c;
        if(!duplicateCheck.add(key)){
            dupIds.add(item.Id);
            if(qtyMap.containsKey(key))
            {
                qtyMap.get(key).add((Integer)item.Application_QTY__c); 
            }
            else 
            {
                List<Integer> qtyList = new List<Integer>();
                qtyList.add((Integer)item.Application_QTY__c);
                
                qtyMap.put(key,qtyList);
            }
        }
    }
    system.debug('dupIds'+dupIds);
    system.debug('qtyMap'+qtyMap);

    Map<String,Integer> sumMap =new Map<String,Integer>();
    
    for(String k:qtyMap.keySet()){
        Integer sum=0;
        for(Integer i :qtyMap.get(k)){
              sum+=i;
              sumMap.put(k, sum);  
        }
    }
    system.debug('sumMap'+sumMap);
    
    //删除重复记录
    delete [SELECT Id from RTV_Order_Item__c where Id IN :dupIds];

     //更新保留记录的Application QTY
     List<RTV_Order_Item__c> upItemList = new List<RTV_Order_Item__c>();
     for(RTV_Order_Item__c item : [SELECT Id, Name,RTV_Order__c, Application_QTY__c,POS_SKU__c FROM RTV_Order_Item__c WHERE RTV_Order__c IN :orderIds]){
        if(sumMap.containsKey(item.RTV_Order__c + item.POS_SKU__c)){
            RTV_Order_Item__c obj = new RTV_Order_Item__c();
            obj.Id = item.Id;
            obj.Application_QTY__c = item.Application_QTY__c + sumMap.get(item.RTV_Order__c + item.POS_SKU__c);
            upItemList.add(obj);
        }
     }

     update upItemList;

}