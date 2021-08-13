@IsTest(isParallel=true)
public class Test_Trigger_RMS_Access_DEF_Summary {
    @isTest
    public static void test() {
        RMS_Account_Group__c accGrp = new RMS_Account_Group__c();
        accGrp.Name = 'xxx';
        accGrp.OwnerId = UserInfo.getUserId();
        insert accGrp;
        
        RTV_DEF_Summary__c summary = new RTV_DEF_Summary__c();
        summary.Year__c = String.valueOf(Date.today().year());
        summary.Month__c = Date.today().month();
        summary.Account_Group__c = accGrp.Id;
        insert summary;
    }
}