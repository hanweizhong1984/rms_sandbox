@IsTest(isParallel=true)
public class Test_Trigger_RMS_RP_SummaryBudget_Total {
    @isTest
    public static void test() {
        RMS_Account_Group__c acg = new RMS_Account_Group__c();
        insert acg;
        
        RTV_Program__c program = new RTV_Program__c();
        insert program;
        
        RTV_RP_Summary_Budget__c budget = new RTV_RP_Summary_Budget__c();
        budget.Return_Program__c = program.Id;
        budget.Account_Group__c = acg.Id;
        insert budget;
    }
}