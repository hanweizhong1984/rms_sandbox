trigger RMS_OrderItem_TotalBudget on RTV_Order_Item__c (after insert, after update, after delete) {

    Set<Id> ALLOrderSet = new Set<Id>();
    Set<Id> DTCProgramSet = new Set<Id>();
    Set<Id> WSLProgramSet = new Set<Id>();
    Map<Id,RTV_Order__c> orderMap = new Map<Id,RTV_Order__c>();
    Map<String,Decimal> BudgetQtyMap = new Map<String,Decimal>();
    Map<String,Decimal> BudgetNetMap = new Map<String,Decimal>();

    List<RTV_Order_Item__c> workingItems = Trigger.isDelete? trigger.old: trigger.new;
    
    // 待更新的SkuBudget
    Map<Id, RTV_RP_Sku_Budget__c> updSkuBudgets = new Map<Id, RTV_RP_Sku_Budget__c>();
    
    // 遍历处理的item
    for (RTV_Order_Item__c item: workingItems) {
        RTV_Order_Item__c oldItem = Trigger.isUpdate? trigger.oldMap.get(item.Id): null;
        
        // 新增或删除时
        if (Trigger.isInsert || Trigger.isDelete || 
        // 或者更新ApplicationQTY时
        (Trigger.isUpdate && (
            item.Application_QTY__c != oldItem.Application_QTY__c ||
            item.Application_Amount__c != oldItem.Application_Amount__c ||
            item.MSRP__c != oldItem.MSRP__c ||
            item.BudgetQTY__c!=oldItem.BudgetQTY__c //触发旧数据重新更新sku预算数量（开关）
        ))) {
            // 准备更新关联的SkuBudget
            if (item.Sku_Budget__c != null) {
                RTV_RP_Sku_Budget__c skuBgt = new RTV_RP_Sku_Budget__c();
                skuBgt.Id = item.Sku_Budget__c;
                skuBgt.Application_QTY__c = 0;
                skuBgt.Application_MSRP__c = 0;
                skuBgt.Application_NET__c = 0;
                updSkuBudgets.put(skuBgt.Id, skuBgt);
            }

            //退仓订单
            if(item.RTV_Order__c!=null){
                ALLOrderSet.add(item.RTV_Order__c);
            }
        }
    }

    if(!ALLOrderSet.isEmpty()){
        for(RTV_Order__c order:[
            SELECT Id, Return_Summary__r.RTV_Program__c,Return_Summary__r.RTV_Program__r.Name,
            Store_Code__c,Sold_To__r.Name,Return_Summary__r.Account_Group__c,
            Return_Summary__r.RTV_Program__r.DTC_Type__c,
            Return_Summary__r.Account_Group__r.Name
            FROM RTV_Order__c 
            WHERE Id IN :ALLOrderSet
        ]){
            if(!orderMap.containsKey(order.Id))
            {
                orderMap.put(order.Id,order);
            }
            if(order.Return_Summary__r.RTV_Program__r.DTC_Type__c=='CFS' || order.Return_Summary__r.RTV_Program__r.DTC_Type__c=='Digital'){
                DTCProgramSet.add(order.Return_Summary__r.RTV_Program__c);
            }else{
                WSLProgramSet.add(order.Return_Summary__r.RTV_Program__c);
            }
        }
    }

    if(!DTCProgramSet.isEmpty()){
        for(AggregateResult obj:[
            SELECT RP_Ship_To__r.Ship_To__r.DTC_Code__c dtcCode,
            SKU_Material_Code__c,
            Return_Program__r.Name programName,
            Summary_Budget__c, 
            SUM(Budget_NET__c) budgetNet,  
            SUM(Budget_QTY__c) budgetQTY
            FROM RTV_RP_SKU_Budget__c 
            WHERE Return_Program__c IN  :DTCProgramSet
            GROUP BY Return_Program__r.Name,Summary_Budget__c,SKU_Material_Code__c,RP_Ship_To__r.Ship_To__r.DTC_Code__c
            ]){
                Decimal budgetQty = (Decimal)obj.get('budgetQty') != null? (Decimal)obj.get('budgetQty'): 0;
                String dtcCode=obj.get('dtcCode')!=null?(String)obj.get('dtcCode'):'';
                String programName = obj.get('programName')!=null?(String)obj.get('programName'):'';
                String material= obj.get('SKU_Material_Code__c')!=null?(String)obj.get('SKU_Material_Code__c'):'';
                //DIG
                if(dtcCode==null){
                    String key = programName+material;
                    if(!BudgetQtyMap.containsKey(key))
                    {
                        BudgetQtyMap.put(key,budgetQty);
                    }     
                }else{
                    //CFS
                    String key = programName+dtcCode+material;
                    if(!BudgetQtyMap.containsKey(key))
                    {
                        BudgetQtyMap.put(key,budgetQty);
                    }
                }
            }
    }

    if(!WSLProgramSet.isEmpty()){
        for(AggregateResult grp:[
            SELECT Account_Group__r.Name accountName,
            SKU_Material_Code__c,
            Return_Program__r.Name programName,
            SUM(Budget_NET__c) budgetNet,  
            SUM(Budget_QTY__c) budgetQTY
            FROM RTV_RP_SKU_Budget__c 
            WHERE Return_Program__c IN  : WSLProgramSet
            GROUP BY Return_Program__r.Name,SKU_Material_Code__c,Account_Group__r.Name
            ]){
                Decimal budgetQty = (Decimal)grp.get('budgetQty') != null? (Decimal)grp.get('budgetQty'): 0;
                Decimal budgetNet = (Decimal)grp.get('budgetNet') != null? ((Decimal)grp.get('budgetNet')).setScale(2, System.RoundingMode.HALF_UP): 0;
                String programName = grp.get('programName')!=null?(String)grp.get('programName'):'';
                String accountName = grp.get('accountName')!=null?(String)grp.get('accountName'):'';
                String material= grp.get('SKU_Material_Code__c')!=null?(String)grp.get('SKU_Material_Code__c'):'';
                String key = programName+accountName+material;
                if(!BudgetQtyMap.containsKey(key)&&!BudgetNetMap.containsKey(key))
                {
                    BudgetQtyMap.put(key,budgetQty);
                    BudgetNetMap.put(key,budgetNet);
                }        
            }
    }
    system.debug('Trigger.isDelete:'+ Trigger.isDelete);
    if(Trigger.isDelete==false){
    List<RTV_Order_Item__c> updDatas = new List<RTV_Order_Item__c>();
    for (RTV_Order_Item__c item: workingItems) {
        RTV_Order_Item__c updItem=new RTV_Order_Item__c();
        String programName ='';
        String storecode ='';
        String accountName ='';
        String dtcType='';
        String key='';
        if(orderMap.get(item.RTV_Order__c)!=null){
            RTV_Order__c order = orderMap.get(item.RTV_Order__c);
            dtcType=order.Return_Summary__r.RTV_Program__r.DTC_Type__c;
            programName = order.Return_Summary__r.RTV_Program__r.Name;
            accountName= order.Return_Summary__r.Account_Group__r.Name;
            storecode = order.Store_Code__c;
        }
        //DTC
        if (item.IsDTC__c == true){
            key = dtcType=='CFS'? programName+storecode+item.Material_Code__c:programName+item.Material_Code__c;
        
            if(BudgetQtyMap.get(key)!=null){
                updItem.Id = item.Id;
                updItem.BudgetQTY__c = BudgetQtyMap.get(key);
                updDatas.add(updItem);
            }
        }else{
        //WSL
            key =programName+accountName+item.Material_Code__c;
            if(BudgetQtyMap.get(key)!=null){
                updItem.Id = item.Id;
                updItem.BudgetQTY__c = BudgetQtyMap.get(key);
                updItem.BudgetAmount__c =BudgetNetMap.get(key);
                updDatas.add(updItem);
            }
        }
    }
    update updDatas;

    }

    system.debug('updSkuBudgets:'+updSkuBudgets);
    // 更想SkuBudget中的Application信息
    if (!updSkuBudgets.isEmpty()) {
        //获取summary budget为条件的预算金额，因为相同meterial会有重复数据，所以需要按meterial将其数量和金额汇总，在上传pk时，去和order item的金额（汇总）进行对比判断是否超额 （2021/8/8修改）
        List<RTV_RP_SKU_Budget__c> skubudgets = [SELECT Summary_Budget__c FROM RTV_RP_SKU_Budget__c WHERE Id IN :updSkuBudgets.keyset()];
        Map<String, Decimal> budgetNetMap = new Map<String, Decimal>();
        Map<String, Decimal> budgetQTYMap = new Map<String, Decimal>();
        for(AggregateResult obj:[
            SELECT SKU_Material_Code__c,
            Return_Program__r.RecordType.Name recordType,
            Summary_Budget__c, 
            SUM(Budget_NET__c) budgetNet,  
            SUM(Budget_QTY__c) budgetQTY,
            MIN(Return_Program__r.Tolerance__c) tolerance 
            FROM RTV_RP_SKU_Budget__c 
            WHERE Summary_Budget__c = :skubudgets[0].Summary_Budget__c
            GROUP BY Return_Program__r.RecordType.Name,Summary_Budget__c,SKU_Material_Code__c
        ]){
            Decimal budgetNet = (Decimal)obj.get('budgetNet') != null? 
                ((Decimal)obj.get('budgetNet')).setScale(2, System.RoundingMode.HALF_UP): 0;
            Decimal budgetQty = (Decimal)obj.get('budgetQty') != null? 
                (Decimal)obj.get('budgetQty'): 0;
            String recordType = obj.get('recordType')!=null?(String)obj.get('recordType'):'';
            Decimal tolerance = (Decimal)obj.get('tolerance')!=null?((Decimal)obj.get('tolerance')).setScale(2, System.RoundingMode.HALF_UP):0;
            //非金的退货商品数量可以+10%的buffer
            if(recordType!=''&&(recordType=='WSL Discount Takeback Off Policy'||(String)obj.get('recordType')=='WSL Full Takeback Off Policy')){
                budgetQty=budgetQty*(1+tolerance);
            }
            budgetNetMap.put((String)obj.get('SKU_Material_Code__c'), budgetNet);
            budgetQTYMap.put((String)obj.get('SKU_Material_Code__c'), budgetQTY);
        }

           
        // 检索目标SkuBudget以及其下的item合计
        for (AggregateResult grp: [
            SELECT SKU_Budget__c,
                Material_Code__c,
                SKU_Budget__r.RP_Ship_To__r.Ship_To__r.Name ShipToName,
                SKU_Budget__r.Sold_To__r.Name SoldToName,
                SKU_Budget__r.Account_Group__r.Name AccGrpName,
                // MIN(SKU_Budget__r.Budget_QTY__c) budgetQty, 
                MIN(SKU_Budget__r.Budget_MSRP__c) budgetMsrp, 
                // MIN(SKU_Budget__r.Budget_NET__c) budgetNet, 
                SUM(Application_QTY__c) sumApplyQty,
                SUM(MSRP__c) sumApplyMsrp,
                SUM(Application_Amount__c) sumApplyNet
            FROM RTV_Order_Item__c
            WHERE SKU_Budget__c IN :updSkuBudgets.KeySet()
            AND RTV_Order__r.IsDTC__c = false
            GROUP BY SKU_Budget__c, Material_Code__c,
                SKU_Budget__r.RP_Ship_To__r.Ship_To__r.Name,
                SKU_Budget__r.Sold_To__r.Name,
                SKU_Budget__r.Account_Group__r.Name
        ]) {
            // Long budgetQty = (Decimal)grp.get('budgetQty') != null? 
            //     ((Decimal)grp.get('budgetQty')).round(): 0;
                
            Decimal budgetMsrp = (Decimal)grp.get('budgetMsrp') != null? 
                ((Decimal)grp.get('budgetMsrp')).setScale(2, System.RoundingMode.HALF_UP): 0;
                
            // Decimal budgetNet = (Decimal)grp.get('budgetNet') != null? 
            //     ((Decimal)grp.get('budgetNet')).setScale(2, System.RoundingMode.HALF_UP): 0;
                
            Long sumApplyQty = (Decimal)grp.get('sumApplyQty') != null? 
                ((Decimal)grp.get('sumApplyQty')).round(): 0;
                
            Decimal sumApplyMsrp = (Decimal)grp.get('sumApplyMsrp') != null? 
                ((Decimal)grp.get('sumApplyMsrp')).setScale(2, System.RoundingMode.HALF_UP): 0;
                
            Decimal sumApplyNet = (Decimal)grp.get('sumApplyNet') != null? 
                ((Decimal)grp.get('sumApplyNet')).setScale(2, System.RoundingMode.HALF_UP): 0;
            
            String Material = (String)grp.get('Material_Code__c');
            Decimal budgetNet = budgetNetMap.get(Material);
            Decimal budgetQty = budgetQTYMap.get(Material);
            // QTY超出预算时
            if (budgetQty > 0 && sumApplyQty > budgetQty) {
                workingItems[0].addError('已超出预算数量 ' 
                     + '(预算数量=' + budgetQty + ')'
                     + '(实际数量=' + sumApplyQty + ')'
                     + '(货品号=' + (String)grp.get('Material_Code__c') + ')'
                 );
                //workingItems[0].addError('(货品号=' + (String)grp.get('Material_Code__c') + ')已超出预算数量');
            }
            // $NET(乘以QTY的总金额)超出预算时
            // if (budgetNet > 0 && sumApplyNet > budgetNet) {
            //     workingItems[0].addError('已超出预算 ' 
            //         + '(预算总金额=' + budgetNet + ')'
            //         + '(实际总金额=' + sumApplyNet + ')'
            //         + '(货品号=' + (String)grp.get('Material_Code__c') + ')'
            //     );
            // }
            
            // 更新skuBudget
            RTV_RP_Sku_Budget__c skuBudget = updSkuBudgets.get((Id)grp.get('SKU_Budget__c'));
            skuBudget.Application_QTY__c = (Decimal)grp.get('sumApplyQty');
            skuBudget.Application_MSRP__c = (Decimal)grp.get('sumApplyMsrp');
            skuBudget.Application_NET__c = (Decimal)grp.get('sumApplyNet');
        }
        // 更新（有addError()时会自动不执行）
        update updSkuBudgets.values();
    }
}