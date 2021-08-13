@IsTest(SeeAllData=true)
public class Test_Trigger_RMS_Owner_SoldTo {
    @IsTest
    public static void test() {
        
        RMS_Sold_To__c soldto = new RMS_Sold_To__c();
        soldto.Name = 'xxxxx';
        insert soldto;
        
        RMS_Ship_To__c shipto = new RMS_Ship_To__c();
        shipto.Sold_To_Code__c = soldto.Id;
        shipto.Name = 'xxxxx';
        insert shipto;
        
        soldto.OwnerId = [SELECT Id FROM User WHERE Id != :UserInfo.getUserId() LIMIT 1][0].Id;
        update soldto;
    }
}