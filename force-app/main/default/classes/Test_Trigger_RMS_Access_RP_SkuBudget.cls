@IsTest(isParallel=true)
public class Test_Trigger_RMS_Access_RP_SkuBudget {
    @IsTest
    static void test() {
        RTV_RP_Sku_Budget__c budget = new RTV_RP_Sku_Budget__c();
        budget.SKU_Material_Code__c = 'xxxxxx';
        budget.OwnerId = UserInfo.getUserId();
        insert budget;
    }
}