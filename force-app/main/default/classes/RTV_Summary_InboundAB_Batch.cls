public class RTV_Summary_InboundAB_Batch implements Database.Batchable<SObject>, Database.Stateful{
    
    private final Set<Id> orderIds;
    public RTV_Summary_InboundAB_Batch(Set<Id> orderIds) {
        this.orderIds = orderIds;
    }

    /** 开始 */
    public Database.QueryLocator start(Database.BatchableContext info){
        return Database.getQueryLocator([
            SELECT Id, Inspect_QTY_A__c, Inspect_QTY_B__c, Inspect_QTY_D__c
            FROM RTV_Order_Item__c
            WHERE RTV_Order__c IN :this.orderIds
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
            upItem.Inbound_QTY__c =  item.Inspect_QTY_A__c + item.Inspect_QTY_B__c;
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