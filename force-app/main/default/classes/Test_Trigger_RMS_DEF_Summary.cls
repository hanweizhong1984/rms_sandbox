@IsTest(isParallel=true)
public class Test_Trigger_RMS_DEF_Summary {
    @IsTest
    static void test() {
        RMS_Account_Group__c acg = new RMS_Account_Group__c();
        acg.Name = '00)CC';
        insert acg;
        
        RTV_DEF_Summary__c summary = new RTV_DEF_Summary__c();
        summary.Year__c = '2019';
        summary.Month__c = 3;
        insert summary;
        
        summary = new RTV_DEF_Summary__c();
        summary.Year__c = '2019';
        summary.Month__c = 0;
        summary.Account_Group__c = acg.Id;
        insert summary;
    }
}