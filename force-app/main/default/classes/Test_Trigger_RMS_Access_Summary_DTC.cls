@IsTest(isParallel=true)
public class Test_Trigger_RMS_Access_Summary_DTC {
    @IsTest
    public static void test() {
        RTV_Summary__c summary = new RTV_SUmmary__c();
        insert summary;
    }
}