@IsTest(isParallel=true)
public class Test_Trigger_RMS_Order_UnDeleted {
    @IsTest
    public static void test() {
        RTV_Order__c order = new RTV_Order__c();
        order.Name = 'xxx';
        order.Status__c = 'Post to LF';
        insert order;
        try {delete order;} catch (Exception err) {}
    }
}