@IsTest(isParallel=true)
public class Test_Trigger_RMS_OrderInsp_Total {
    @IsTest
    public static void test() {
        RTV_Order__c order = new RTV_Order__c();
        insert order;
        
        RTV_Order_Item__c item = new RTV_Order_Item__c();
        item.RTV_Order__c = order.Id;
        item.Material_Code__c = 'PDT000001';
        item.BU_2__c = 'AP';
        item.Season_Code_CN__c = '20Q1';
        item.SKU_Size_US__c = 'XL';
        insert item;
        
        RTV_Order_Inspection__c insp = new RTV_Order_Inspection__c();
        insp.RTV_Order_Item__c = item.Id;
        insp.A__c = 15;
        insert insp;
        
        insp.A__c = 16;
        update insp;
        
        delete insp;
    }
}