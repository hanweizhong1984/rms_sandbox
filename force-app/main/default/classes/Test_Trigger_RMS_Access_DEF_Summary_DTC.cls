@IsTest(isParallel=true)
public class Test_Trigger_RMS_Access_DEF_Summary_DTC {
    @isTest
    public static void test() {
        RTV_DEF_Summary__c summary = new RTV_DEF_Summary__c();
        summary.Year__c = '2021';
        summary.Month__c = 3;
        insert summary;
    }
}