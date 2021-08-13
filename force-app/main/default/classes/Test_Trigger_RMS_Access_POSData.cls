@IsTest(isParallel=true)
public class Test_Trigger_RMS_Access_POSData {
    @isTest
    public static void test() {
        RTV_POS_Data__c pos = new RTV_POS_Data__c();
        insert pos;
        
        pos = new RTV_POS_Data__c();
        pos.Name = '4691';
        insert pos;
    }
}