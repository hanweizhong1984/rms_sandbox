@IsTest(isParallel=true)
public class Test_RMS_DeleteRecord_Batch {
    @isTest
    public static void test() {
        // PS：测试batch需要 Test.StartTest() 和 Test.StopTest()
        Test.StartTest();
        
        RTV_Order__c order = new RTV_Order__c();
        insert order;
        Database.executeBatch(new RMS_DeleteRecord_Batch('SELECT Id FROM RTV_Order__c WHERE Id = \'' + order.Id + '\''));
        
        Test.StopTest();
    }
}