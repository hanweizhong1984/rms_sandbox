@IsTest(isParallel=true)
public class Test_Trigger_RTV_POS_Data_AuthCodeChange {
    @isTest
    public static void test() {
        RTV_POS_Data__c pos = new RTV_POS_Data__c();
        insert pos;
        
        pos.Order_No__c = 'xx';
        update pos;
    }
}