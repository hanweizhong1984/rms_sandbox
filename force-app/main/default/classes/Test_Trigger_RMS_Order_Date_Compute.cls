@IsTest(isParallel=true)
public class Test_Trigger_RMS_Order_Date_Compute {
    @isTest
    public static void test() {
        RTV_Summary__c summary = new RTV_Summary__c();
        insert summary;
        
        // 创建order
        RTV_Order__c order = new RTV_Order__c();
        order.Name = RMS_CommonUtil.order_getCode('xxx', 'xxxxx', 'xxx');
        order.Return_Summary__c = summary.Id;
        order.Status__c = 'Delivery';
        insert order;
        
        // 创建lfOrder
        RTV_LF_Order__c lfOrder = new RTV_LF_Order__c();
        lfOrder.RTV_Order__c = order.Id;
        insert lfOrder;
        
        // 更新到货日
        lfOrder.Arrival_Date__c = System.today();
        update lfOrder;
    }
}