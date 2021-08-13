@IsTest(isParallel=true)
public class Test_Trigger_RMS_Summary_Total {
    @isTest
    public static void test() {
        RTV_Summary__c summary = new RTV_Summary__c();
        insert summary;
        
        summary.Application_QTY__c = 1;
        update summary;
    }
}