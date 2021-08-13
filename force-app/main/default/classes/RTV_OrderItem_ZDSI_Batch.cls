public with sharing class RTV_OrderItem_ZDSI_Batch
implements Database.Batchable<SObject>, Database.Stateful {
  
    List<ID> orderIds = new List<ID>();
    Map<String, Set<Decimal>> zdsiAMap = new Map<String, Set<Decimal>>();
    Map<String, Set<Decimal>> zdsiBMap = new Map<String, Set<Decimal>>();
    Map<String, Set<Decimal>> zdsiDMap = new Map<String, Set<Decimal>>();
    Map<String, List<RTV_Order_Item__c>> zdsiItemAMap = new Map<String, List<RTV_Order_Item__c>>();
    Map<String, List<RTV_Order_Item__c>> zdsiItemBMap = new Map<String, List<RTV_Order_Item__c>>();
    Map<String, List<RTV_Order_Item__c>> zdsiItemDMap = new Map<String, List<RTV_Order_Item__c>>();
    Map<ID, RTV_Order_Item__c> orderMap = new Map<ID, RTV_Order_Item__c>();

    public RTV_OrderItem_ZDSI_Batch(List<ID> orderIds) {
        this.orderIds = orderIds;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        System.debug('start...');
        return Database.getQueryLocator(
            [SELECT ID, Material_Code__c, BU_2__c, Selling_Unit_Price__c, Final_Price_A__c, Final_Price_B__c, Final_Price_D__c 
            FROM RTV_Order_Item__c where RTV_Order__c IN :this.orderIds]);
    }

    public void execute(Database.BatchableContext BC, List<RTV_Order_Item__c> scope){
        System.debug('execute...' + scope.size());

        orderMap = new Map<ID, RTV_Order_Item__c>();

        Map<String, List<RTV_Order_Item__c>> itemMap = new Map<String, List<RTV_Order_Item__c>>();
        for(RTV_Order_Item__c obj : scope){
            if(itemMap.ContainsKey(obj.Material_Code__c)){
                itemMap.get(obj.Material_Code__c).add(obj);
            }else {
                itemMap.put(obj.Material_Code__c, new List<RTV_Order_Item__c>{obj});
            }
        }

        // 最新的Product季节码
        List<AggregateResult>  temps = [
            SELECT Material_Code__c, MAX(Season_Code_CN__c) MaxSeason FROM RMS_Product__c
            WHERE Material_Code__c IN :itemMap.keySet() GROUP BY Material_Code__c
        ];

        Set<String> names = new Set<String>();
        for (AggregateResult obj : temps) {
            String maxseason = (String)obj.get('MaxSeason');
            String season_us = maxseason.substring(2) == 'Q1' ? 'SP' + maxseason.substring(0,2):
                maxseason.substring(2) == 'Q2' ? 'SU' + maxseason.substring(0,2):
                maxseason.substring(2) == 'Q3' ? 'FA' + maxseason.substring(0,2):
                maxseason.substring(2) == 'Q4' ? 'HO' + maxseason.substring(0,2):
                null;
            names.add((String)obj.get('Material_Code__c') + '_' + season_us);
        }
        System.debug('names...' + names);

        // 当前税率
        Decimal nowTaxRate = ConverseRMS__c.getOrgDefaults().TaxRate__c;
        // 最新的MSRP
        for (RMS_Product__c pdt: [
            SELECT Material_Code__c, MSRP__c, BUCN__c
            FROM RMS_Product__c 
            WHERE Name IN :names
        ]) {
            /* 
            ZDSI计算公式
                ZDSI = ZWSL - FINAL Price （只计算单价, 不用乘以QTY）																						
                ZWSL　分别计算 AP/AC  和  FW																																
			        ZWSL （APAC） =  Master Data中最新的MSRP * 0.55 / 全局变量中的税率																													
                    ZWSL （FW）   =  Master Data中最新的MSRP * 0.58 / 全局变量中的税率
            */
            Decimal zwsl = 0;
            if(pdt.BUCN__c == 'APP' || pdt.BUCN__c == 'ACC'){
                zwsl = (pdt.MSRP__c * 0.55 / nowTaxRate).setScale(2, System.RoundingMode.HALF_UP);
            }else {
                zwsl = (pdt.MSRP__c * 0.58 / nowTaxRate).setScale(2, System.RoundingMode.HALF_UP);
            }

            if(itemMap.ContainsKey(pdt.Material_Code__c)){
                for (RTV_Order_Item__c item : itemMap.get(pdt.Material_Code__c)) {
                    Decimal fpriceA = item.Final_Price_A__c == null ? 0 : item.Final_Price_A__c;
                    Decimal fpriceB = item.Final_Price_B__c == null ? 0 : item.Final_Price_B__c;
                    Decimal fpriceD = item.Final_Price_D__c == null ? 0 : item.Final_Price_D__c;

                    item.Condition_Value_ZDSI_A__c = zwsl - fpriceA;
                    item.Condition_Value_ZDSI_B__c = zwsl - fpriceB;
                    item.Condition_Value_ZDSI_D__c = zwsl - fpriceD;

                    item.Remark_A__c = '';
                    item.Remark_B__c = '';
                    item.Remark_D__c = '';

                    //情况二：ZDSI为负数值
                    if(item.Condition_Value_ZDSI_A__c < 0){
                        item.Remark_A__c = 'ZDSI为负数值;';
                    }
                    if(item.Condition_Value_ZDSI_B__c < 0){
                        item.Remark_B__c = 'ZDSI为负数值;';
                    }
                    if(item.Condition_Value_ZDSI_D__c < 0){
                        item.Remark_D__c = 'ZDSI为负数值;';
                    }
                    orderMap.put(item.Id, item);

                    checkZDSI(pdt.Material_Code__c, item, 'A');
                    checkZDSI(pdt.Material_Code__c, item, 'B');
                    checkZDSI(pdt.Material_Code__c, item, 'D');
                }
            }
        }

        // 更新ZDSI
        if(!orderMap.isEmpty()){
            update orderMap.Values();
        }
    }

    /* 情况一：ZDSI存在多个值 */
    private void checkZDSI(String materialCode, RTV_Order_Item__c item, String level){

        Map<String, Set<Decimal>> zdsiMap = level == 'A' ? zdsiAMap : level == 'B' ? zdsiBMap : zdsiDMap;
        Map<String, List<RTV_Order_Item__c>> zdsiItemMap = level == 'A' ? zdsiItemAMap : level == 'B' ? zdsiItemBMap : zdsiItemDMap;

        if(zdsiMap.containsKey(materialCode)){
            if(level == 'A'){
                zdsiMap.get(materialCode).add(item.Condition_Value_ZDSI_A__c);
            } else if(level == 'B'){
                zdsiMap.get(materialCode).add(item.Condition_Value_ZDSI_B__c);
            } else {
                zdsiMap.get(materialCode).add(item.Condition_Value_ZDSI_D__c);
            }
        }else {
            if(level == 'A'){
                zdsiMap.put(materialCode,new Set<Decimal>{item.Condition_Value_ZDSI_A__c});
            } else if(level == 'B'){
                zdsiMap.put(materialCode,new Set<Decimal>{item.Condition_Value_ZDSI_B__c});
            } else {
                zdsiMap.put(materialCode,new Set<Decimal>{item.Condition_Value_ZDSI_D__c});
            }
        }

        if(zdsiItemMap.containsKey(materialCode)){
            zdsiItemMap.get(materialCode).add(item);
        }else {
            zdsiItemMap.put(materialCode,new List<RTV_Order_Item__c>{item});
        }

        if(zdsiMap.get(materialCode).size() > 1){
            for (RTV_Order_Item__c oItem : zdsiItemMap.get(materialCode)) {
                if(level == 'A'){
                    if(oItem.Condition_Value_ZDSI_A__c < 0){
                        oItem.Remark_A__c = 'ZDSI存在多个值;ZDSI为负数值;';
                        orderMap.put(oItem.Id, oItem);
                    }else {
                        oItem.Remark_A__c = 'ZDSI存在多个值;';
                        orderMap.put(oItem.Id, oItem);
                    }
                } else if(level == 'B'){
                    if(oItem.Condition_Value_ZDSI_B__c < 0){
                        oItem.Remark_B__c = 'ZDSI存在多个值;ZDSI为负数值;';
                        orderMap.put(oItem.Id, oItem);
                    }else {
                        oItem.Remark_B__c = 'ZDSI存在多个值;';
                        orderMap.put(oItem.Id, oItem);
                    }
                } else {
                    if(oItem.Condition_Value_ZDSI_D__c < 0){
                        oItem.Remark_D__c = 'ZDSI存在多个值;ZDSI为负数值;';
                        orderMap.put(oItem.Id, oItem);
                    }else {
                        oItem.Remark_D__c = 'ZDSI存在多个值;';
                        orderMap.put(oItem.Id, oItem);
                    }
                }
            }
        }
    }

    public void finish(Database.BatchableContext BC){
        //Nothing
    }
}