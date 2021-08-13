@IsTest(isParallel=true)
public class Test_Trigger_RTV_Program_InitRebuy {
    @isTest
    public static void test() {
        RMS_Account_Group__c acgCC = new RMS_Account_Group__c();
        acgCC.Name = '00)CC';
        insert acgCC;
        
        RTV_Program__c program = new RTV_Program__c();
        program.RecordTypeId = RMS_CommonUtil.getRecordTypes('RTV_Program__c').get('CFS DTC Takeback Kick Off').Id;
        program.DTC_Rebuy__c = true;
        insert program;
    }
}