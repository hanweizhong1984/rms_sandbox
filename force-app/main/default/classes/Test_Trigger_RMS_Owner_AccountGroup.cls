@IsTest(SeeAllData=true)
public class Test_Trigger_RMS_Owner_AccountGroup {
    @IsTest
    public static void test() {
        RMS_Account_Group__c acg = new RMS_Account_Group__c();
        acg.Name = 'xxx';
        insert acg;
        
        RMS_Sold_To__c soldto = new RMS_Sold_To__c();
        soldto.Account_Group__c = acg.Id;
        soldto.Name = 'xxxxx';
        insert soldto;
        
        acg.OwnerId = [SELECT Id FROM User WHERE Id != :UserInfo.getUserId() LIMIT 1][0].Id;
        update acg;
    }
}