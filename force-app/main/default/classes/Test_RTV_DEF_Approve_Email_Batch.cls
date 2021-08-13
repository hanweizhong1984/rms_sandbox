@IsTest(isParallel=true)
public  class Test_RTV_DEF_Approve_Email_Batch {
    @isTest
    public static void test() {
        RTV_Order__c order = new RTV_Order__c();
        order.Ship_To_Outbound_Emails__c = 'xx@xxxx.xxxx';
        order.Name = 'xxx';
        order.Status__c = 'Insp Wait Approval';
        insert order;
        
        RTV_DEF_Approve_Email_Batch batch = new RTV_DEF_Approve_Email_Batch(new Set<Id>{order.Id});
        Test.StartTest();
        Database.executeBatch(batch, 1);
        Test.StopTest();
    }
}