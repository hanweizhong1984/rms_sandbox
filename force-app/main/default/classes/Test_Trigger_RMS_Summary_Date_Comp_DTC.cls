/** RMS_Summary_Date_Compute_DTC */
@IsTest(isParallel=true)
public class Test_Trigger_RMS_Summary_Date_Comp_DTC {
    @isTest
    public static void test() {
        RTV_Summary__c summary = new RTV_Summary__c();
        insert summary;
    }
}