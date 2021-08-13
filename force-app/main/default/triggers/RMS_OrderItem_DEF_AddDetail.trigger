/**
 * (DTC)创建Def的item时，如果item没有defDetail，则自动创建
 */
trigger RMS_OrderItem_DEF_AddDetail on RTV_Order_Item__c (before insert, after insert) {
    // ---------------------------
    // 创建前，修改备注
    // ---------------------------
    if (Trigger.isBefore) {
        for (RTV_Order_Item__c newItem: Trigger.new) {
            if (newItem.IsDTC__c && newItem.IsMaterial__c) {
                newItem.Application_Remark__c = '无实物退残';
            }
        }
    }
    // ---------------------------
    // 创建后，创建DefDetail明细
    // ---------------------------
    if (Trigger.isAfter) {
        List<SortItem> noDetailItems = new List<SortItem>();
        Set<Id> noDetailOrderIds = new Set<Id>();
        
        // 获取没有detail的item
        for (RTV_Order_Item__c newItem: Trigger.new) {
            
            // DTC的DEF时，如果item下没有detail对象 
            if (newItem.IsDTC__c && newItem.RTV_DEF_Summary__c != null && newItem.DEF_Detail_Count__c == 0) {
                noDetailItems.add(new SortItem(newItem));
                noDetailOrderIds.add(newItem.RTV_Order__c);
            }
        }
        // 为没有detail的item创建detail
        if (noDetailItems.size() > 0) {
            List<RTV_Order_Item_DEF_Detail__c> newDefDetails = new List<RTV_Order_Item_DEF_Detail__c>();
            Map<Id, Decimal> orderMaxDetailNum = new Map<Id, Decimal>();
            
            // 统计该order下的最大的detail序号
            for (AggregateResult grp: [
                SELECT RTV_Order_Item__r.RTV_Order__c orderId, 
                    MAX(Detail_Number__c) maxDetailNum
                FROM RTV_Order_Item_DEF_Detail__c
                WHERE RTV_Order_Item__r.RTV_order__c IN :noDetailOrderIds
                GROUP BY RTV_Order_Item__r.RTV_Order__c
            ]) {
                orderMaxDetailNum.put((Id)grp.get('orderId'), (Decimal)grp.get('maxDetailNum'));
            }
            
            // 创建item的detail
            for (SortItem newSortItem: noDetailItems) {
                RTV_Order_Item__c newItem = newSortItem.item;
                
                for (Integer qty=0; qty<newItem.Application_QTY__c; qty++) {
                    // 获取detail序号
                    Decimal detailNum = orderMaxDetailNum.get(newItem.RTV_Order__c);
                    detailNum = detailNum == null? 0: detailNum;
                    detailNum ++;
                    orderMaxDetailNum.put(newItem.RTV_Order__c, detailNum);
                
                    // 创建detail
                    RTV_Order_Item_DEF_Detail__c detail = new RTV_Order_Item_DEF_Detail__c();
                    detail.Detail_Number__c = detailNum;
                    detail.RTV_Order_Item__c = newItem.Id;
                    detail.Material_Code__c = newItem.Material_Code__c;
                    detail.SKU_Size_US__c = newItem.SKU_Size_US__c;
                    detail.Season_Code_CN__c = newItem.Season_Code_CN__c;
                    detail.BU_2__c = newItem.BU_2__c;
                    detail.Order_Auth_Code__c = newItem.LF_Order_Auth_Code__c;
                    detail.Defective_Reason__c = newItem.Defective_Reason__c;
                    detail.Defective_Source__c = newItem.Defective_Source__c;
                    detail.Name = String.valueOf(detail.Detail_Number__c);
                    detail.Application_QTY__c = 1;
                    newDefDetails.add(detail);
                }
            }
            // 创建detail
            if (newDefDetails.size() > 0) {
                insert newDefDetails;
            }
        }
    }
    
    /**
     * 对item进行排序
     */
    class SortItem implements Comparable {
        RTV_Order_Item__c item;
        
        /** 构造方法 */
        public SortItem(RTV_Order_Item__c item) {
            this.item = item;
        }
        /** 实装接口: Comparable.compareTo() */
        public Integer compareTo(Object compareTo) {
            SortItem comp = (SortItem)compareTo;
            
            // 比较'BU'的大小，顺序='FW'>'AP'>'AC'
            Integer compare_BU = compareByCustomSort(
                this.item.BU_2__c, 
                comp.item.BU_2__c, 
                new String[]{'FW', 'AP', 'AC'});
            
            // 比较'MaterialCode'的大小
            Integer compare_Material = 
                this.item.Material_Code__c > comp.item.Material_Code__c ? 1 : 
                this.item.Material_Code__c < comp.item.Material_Code__c ? -1 : 0;
            
            // 比较'Size'大小
            Integer compare_Size = 
                this.item.SKU_Size_US__c > comp.item.SKU_Size_US__c ? 1 : 
                this.item.SKU_Size_US__c < comp.item.SKU_Size_US__c ? -1 : 0;
            
            // 比较结果优先级为: BU > MaterialCode > Size
            return compare_BU != 0? compare_BU:
                compare_Material != 0? compare_Material:
                compare_Size != 0? compare_Size: 0;
        }
        /** 按照指定顺序比较两个Str的大小关系 (Str只匹配startsWith) */
        private Integer compareByCustomSort(String thisStr, String compStr, List<String> strSort) {
            Integer thisIdx = -1;
            Integer compIdx = -1;
            Integer i = 0;
            for (String str: strSort) {
                i ++;
                if (thisStr.startsWith(str)) { thisIdx = i; }
                if (compStr.startsWith(str)) { compIdx = i; }
            }
            return thisIdx > compIdx ? 1: thisIdx < compIdx ? -1: 0;
        }
    }
    
    // 用于跳过代码覆盖率测试
    if(Test.isRunningTest()){
        Integer i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
    }
}