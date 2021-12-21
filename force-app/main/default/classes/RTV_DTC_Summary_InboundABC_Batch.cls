public with sharing class RTV_DTC_Summary_InboundABC_Batch implements Database.Batchable<SObject>, Database.Stateful{
    public Set<Id> workOrdersIds {get; set;}
    public RTV_DTC_Summary_InboundABC_Batch(Set<Id> workOrdersIds) {
        this.workOrdersIds = workOrdersIds;
    }
     /** 开始 */
     public Database.QueryLocator start(Database.BatchableContext info){
        return Database.getQueryLocator([
            SELECT Id, Inspect_QTY_A__c, Inspect_QTY_B__c, Inspect_QTY_C__c
            FROM RTV_Order_Item__c
            WHERE RTV_Order__c IN :this.workOrdersIds
        ]);
    }

    /** 执行 */
    public void execute(Database.BatchableContext info, List<RTV_Order_Item__c> items){
        List<RTV_Order_Item__c> upItems = new List<RTV_Order_Item__c>();
        // 遍历item
        for (RTV_Order_Item__c item: Items) {
            // 设置inboundQty
            RTV_Order_Item__c upItem = new RTV_Order_Item__c();
            upItem.Id = item.Id;
            upItem.Inbound_QTY__c =  item.Inspect_QTY_A__c + item.Inspect_QTY_B__c + item.Inspect_QTY_C__c;
            upItems.add(upItem);
        }
        update upItems;
    }
    
    /** 结束 */
    public void finish(Database.BatchableContext info){
        // 抛出job执行时统计的异常
        AsyncApexJob job = [SELECT ExtendedStatus FROM AsyncApexJob WHERE Id = :info.getJobId() LIMIT 1];
        if (!String.isEmpty(job.ExtendedStatus)) {
            throw new RMS_CommonUtil.RMSException(job.ExtendedStatus);
        }
    }




}