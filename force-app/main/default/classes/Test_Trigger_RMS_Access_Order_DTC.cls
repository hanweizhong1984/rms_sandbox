@IsTest(isParallel=true)
public class Test_Trigger_RMS_Access_Order_DTC {
    @isTest
    public static void test() {
        RTV_Order__c order = new RTV_Order__c();
        insert order;
    }
}