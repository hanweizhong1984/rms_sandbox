@IsTest(isParallel=true)
public class Test_Trigger_RMS_Order_DTC_PostLF {
    @isTest
    public static void test() {
        RTV_Order__c order = new RTV_Order__c();
        insert order;
        
        order.Application_QTY__c = 1;
        update order;
    }
}