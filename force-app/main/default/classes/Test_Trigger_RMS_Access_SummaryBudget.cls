@IsTest(isParallel=true)
public class Test_Trigger_RMS_Access_SummaryBudget {
    @IsTest
    static void test() {
        RMS_Account_Group__c grp = new RMS_Account_Group__c();
        insert grp;
        
        RTV_RP_Summary_Budget__c budget = new RTV_RP_Summary_Budget__c();
        budget.OwnerId = UserInfo.getUserId();
        budget.Account_Group__c = grp.Id;
        insert budget;
    }
}