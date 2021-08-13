@IsTest(isParallel=true)
public class Test_Trigger_RMS_OrderItem_DEF_AddDetail {
    @isTest
    public static void test() {
        RTV_Order__c order = new RTV_Order__c();
        insert order;
        
        RTV_Order_Item__c item = new RTV_Order_Item__c();
        item.RTV_Order__c = order.Id;
        insert item;
    }
}