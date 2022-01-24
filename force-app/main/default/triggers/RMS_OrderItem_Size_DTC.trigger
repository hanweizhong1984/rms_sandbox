trigger RMS_OrderItem_Size_DTC on RTV_Order_Item__c (before insert) {
    Set<String> APACMaterialSet = new Set<String>();
    // Set<String> ALLMaterialSet = new Set<String>();
    // Set<Id> ALLOrderSet = new Set<Id>();
    // Set<String> ProgramNameSet = new Set<String>();
    // Map<String,Id> SkuBudgetMap = new Map<String,Id>();
    Map<String,RMS_Product__c> productMap =new Map<String,RMS_Product__c>();
    // Map<Id,RTV_Order__c> orderMap = new Map<Id,RTV_Order__c>();
    for (RTV_Order_Item__c item: Trigger.new) {
        if(item.IsDTC__c==true &&(item.BU_2__c=='AP'||item.BU_2__c=='AC')){
            APACMaterialSet.add(item.Material_Code__c);
        }
    }

    if(!APACMaterialSet.isEmpty()){
        for (RMS_Product__c product: [ 
            SELECT Id, Name, Material_Code__c, SKU__c 
            FROM RMS_Product__c 
            WHERE SKU__c IN :APACMaterialSet
        ]){
            if(!productMap.containsKey(product.SKU__c))
            {
                productMap.put(product.SKU__c,product);
            }
        }
        system.debug('productMap'+productMap);
    }

    //获取特殊尺寸（AP）
    Map<String,List<RMS_Size_Mapping__c>> sizeMap =new Map<String,List<RMS_Size_Mapping__c>>();

    for(RMS_Size_Mapping__c item:[
        select Id,BU__c,Material__c,Asia__c,US__c from RMS_Size_Mapping__c
    ]) {            
        if(sizeMap.containsKey(item.Material__c)) {
            sizeMap.get(item.Material__c).add(new RMS_Size_Mapping__c(Id=item.Id,Asia__c=item.Asia__c,US__c=item.US__c));
        } else {
            List<RMS_Size_Mapping__c> slist = new List<RMS_Size_Mapping__c>();
            slist.add(new RMS_Size_Mapping__c(Id=item.Id,Asia__c=item.Asia__c,US__c=item.US__c));
            sizeMap.put(item.Material__c, slist);
        }
    }

    Map<String,String> sizeMap2 = new Map<String,String>();
    for(String material:sizeMap.keySet()){
            for(RMS_Size_Mapping__c item:sizeMap.get(material)){
        String key =material+item.Asia__c;
        String value = item.US__c;
        sizeMap2.put(key,value);
        }
    }

    for (RTV_Order_Item__c item: Trigger.new) {
        if (item.IsDTC__c == true || item.RTV_BaoZun_Seeding__c!=null){
            if(item.SKU_Size_Asia__c != null) {
                item.SKU_Size_US__c = RMS_CommonUtil.size_Asia2Us(item.SKU_Size_Asia__c,item.BU_2__c);
            }
            //将POS机过来的BU为AP/AC的OrderItem的Material Code转换为和BP上传的SKU Budget中的Material保持一致
            if(productMap.get(item.Material_Code__c)!=null){
                item.Material_Code__c= productMap.get(item.Material_Code__c).Material_Code__c;
            }
            String k= item.Material_Code__c+item.SKU_Size_Asia__c;
            if(sizeMap2.containsKey(k)){
                item.SKU_Size_US__c = sizeMap2.get(k);
            }
            // ALLOrderSet.add(item.RTV_Order__c);
            // ALLMaterialSet.add(item.Material_Code__c);
        }
    }
    
    // if(!ALLOrderSet.isEmpty()){
    //     for(RTV_Order__c order:[
    //         SELECT Id, Return_Summary__r.Program_Name__c, Store_Code__c 
    //         FROM RTV_Order__c 
    //         WHERE Id IN :ALLOrderSet
    //     ]){
    //         if(!orderMap.containsKey(order.Id))
    //         {
    //             orderMap.put(order.Id,order);
    //         }
    //         ProgramNameSet.add(order.Return_Summary__r.Program_Name__c);
    //     }
    //     system.debug('orderMap'+orderMap);
    // }

    // if(!ALLMaterialSet.isEmpty()&&!ProgramNameSet.isEmpty()){
    //     for(RTV_RP_SKU_Budget__c sku:[
    //         SELECT Id, Return_Program__r.Name,SKU_Material_Code__c, Store__c, Size__c 
    //         FROM RTV_RP_SKU_Budget__c
    //         WHERE SKU_Material_Code__c IN : ALLMaterialSet
    //         AND Return_Program__r.Name IN : ProgramNameSet
    //     ]){
    //         String Key='';
    //         if(sku.Size__c!=null){
    //             if(sku.Store__c==null){
    //                 Key = sku.Return_Program__r.Name+sku.SKU_Material_Code__c+sku.Size__c;
    //                 if(!SkuBudgetMap.containsKey(Key))
    //                 {
    //                     SkuBudgetMap.put(Key,sku.Id);
    //                 }
    //             }else{
    //                 Key = sku.Return_Program__r.Name+sku.SKU_Material_Code__c+sku.Store__c+sku.Size__c;
    //                 if(!SkuBudgetMap.containsKey(Key))
    //                 {
    //                     SkuBudgetMap.put(Key,sku.Id);
    //                 }
    //             }
    //         }else{
    //             if(sku.Store__c==null){
    //                 Key = sku.Return_Program__r.Name+sku.SKU_Material_Code__c;
    //                 if(!SkuBudgetMap.containsKey(Key))
    //                 {
    //                     SkuBudgetMap.put(Key,sku.Id);
    //                 }
    //             }else{
    //                 Key = sku.Return_Program__r.Name+sku.SKU_Material_Code__c+sku.Store__c;
    //                 if(!SkuBudgetMap.containsKey(Key))
    //                 {
    //                     SkuBudgetMap.put(Key,sku.Id);
    //                 }
    //             }
    //         }
    //     }
    //     system.debug('SkuBudgetMap'+SkuBudgetMap);
    // }
    
    // for (RTV_Order_Item__c item: Trigger.new) {
    //     if (item.IsDTC__c == true || item.RTV_BaoZun_Seeding__c!=null){
    //         //item绑定对应的SKU_Budget__c
    //         String programName ='';
    //         String storecode ='';
    //         if(orderMap.get(item.RTV_Order__c)!=null){
    //             RTV_Order__c order = orderMap.get(item.RTV_Order__c);
    //             programName = order.Return_Summary__r.Program_Name__c;
    //             storecode = order.Store_Code__c;
    //         }
    //         //cfs :skubudget表中material+store+size的场合
    //         String key =programName+item.Material_Code__c+storecode+item.SKU_Size_Asia__c;
    //         if(SkuBudgetMap.get(key)!=null){
    //             item.SKU_Budget__c = SkuBudgetMap.get(key);
    //         }
    //         //cfs :skubudget表中material+store的场合
    //         String key2 =programName+item.Material_Code__c+storecode;
    //         if(SkuBudgetMap.get(key2)!=null){
    //             item.SKU_Budget__c = SkuBudgetMap.get(key2);
    //         }
    //         //dig :skubudget表中material+size的场合
    //         String key3 = programName+item.Material_Code__c+item.SKU_Size_Asia__c;
    //         if(SkuBudgetMap.get(key3)!=null){
    //             item.SKU_Budget__c = SkuBudgetMap.get(key3);
    //         }
    //         //dig :skubudget表中material的场合
    //         String key4 = programName+item.Material_Code__c;
    //         if(SkuBudgetMap.get(key4)!=null){
    //             item.SKU_Budget__c = SkuBudgetMap.get(key4);
    //         }
    //     }
    // }
}