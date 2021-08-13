@IsTest(isParallel=true)
public class Test_Trigger_RMS_Order_PostLF {
    @IsTest
    public static void test() {
        RMS_Account_Group__c acg = new RMS_Account_Group__c();
        acg.Name = '01)YY';
        insert acg;
        
        RTV_Summary__c summary = new RTV_Summary__c();
        summary.Account_Group__c = acg.Id;
        summary.Status__c = 'Ready';
        insert summary;
        
        RTV_Order__c order = new RTV_Order__c();
        order.Return_Summary__c = summary.Id;
        order.Name = 'order';
        order.Status__c = 'Ready';
        order.Earliest_Delivery_Date__c = System.today();
        order.Ship_To_Contact__c = 'xx';
        order.Ship_To_Phone1__c = '13012341234';
        order.Ship_To_Phone2__c = '13012341234';
        order.Ship_To_Address__c = 'xx';
        order.Ship_To_Outbound_Emails__c = 'xx@xx.xx';
        order.Application_QTY__c = 123.45;
        order.OrderPTLF__c = false;
        insert order;
        
        RTV_Order_Item__c item = new RTV_Order_Item__c();
        item.RTV_Order__c = order.id;
        item.Name = 'TestItem000';
        item.Material_Code__c = 'PDT000001';
        item.SKU_BU__c = 'APP';
        item.BU_2__c = 'A';
        item.Season_Code_CN__c = '20Q1';
        item.SKU_Size_US__c = 'XL';
        item.MSRP__c = 123.45;
        item.TradeTerm__c = 0.95;
        item.NET__c = 123.45;
        insert item;
        
        order.OrderPTLF__c = true;
        order.Status__c = 'POST to LF';
        update order;
        
        
        RTV_Order__c order2 = new RTV_Order__c();
        order2.Return_Summary__c = summary.Id;
        order2.Name = 'order2';
        order2.Status__c = 'Ready';
        order2.Earliest_Delivery_Date__c = System.today();
        order2.Ship_To_Contact__c = 'xx';
        order2.Ship_To_Phone1__c = '13012341234';
        order2.Ship_To_Phone2__c = '13012341234';
        order2.Ship_To_Address__c = 'xx';
        order2.Ship_To_Outbound_Emails__c = 'xx@xx.xx';
        order2.Application_QTY__c = 123.45;
        order2.OrderPTLF__c = false;
        insert order2;
        
        order2.OrderPTLF__c = true;
        order2.Status__c = 'POST to LF';
        update order;
    }
}