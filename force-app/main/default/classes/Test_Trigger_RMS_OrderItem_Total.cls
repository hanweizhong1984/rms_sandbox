@IsTest(isParallel=true)
public class Test_Trigger_RMS_OrderItem_Total {
    @IsTest
    public static void test() {
        RTV_Summary__c summary = new RTV_Summary__c();
        insert summary;
        
        RTV_Order__c order = new RTV_Order__c();
        order.Return_Summary__c = summary.Id;
        insert order;
        
        RTV_Order_Item__c item = new RTV_Order_Item__c();
        item.RTV_Order__c = order.id;
        item.Name = 'TestItem000';
        item.Material_Code__c = 'PDT000001';
        item.SKU_BU__c = 'APP';
        item.BU_2__c = 'A';
        item.Season_Code_CN__c = '20Q1';
        item.SKU_Size_US__c = 'XL';
        item.Application_QTY__c = 12345;
        item.MSRP__c = 123.45;
        item.TradeTerm__c = 0.95;
        item.NET__c = 123.45;
        insert item;
        
        item.Application_QTY__c = 456;
        update item;
        
        delete item;
    }
}