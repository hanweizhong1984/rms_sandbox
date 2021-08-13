@IsTest(isParallel=true)
public class Test_Trigger_RMS_OrderItem_ComputePrice {
    @IsTest
    public static void test() {
        RTV_Summary__c summary = new RTV_Summary__c();
        insert summary;
        
        RTV_Order__c order = new RTV_Order__c();
        order.Return_Summary__c = summary.Id;
        insert order;
        
        RTV_Order_Item__c item = new RTV_Order_Item__c();
        item.RTV_Order__c = order.id;
        item.Material_Code__c = 'PDT000001';
        item.BU_2__c = 'A';
        item.Season_Code_CN__c = '20Q1';
        item.SKU_Size_US__c = 'XL';
        item.Selling_Unit_Price__c = 33.45;
        item.SP_TaxRate__c = 1.13;
        insert item;
        
        item.Selling_Unit_Price__c = 123.45;
        item.Inspect_QTY_A__c = 2;
        item.Inspect_QTY_B__c = 3;
        update item;
        
        item.Selling_Type__c = 'T.B.D';
        item.Selling_Unit_Price__c = 0;
        update item;
        
        item.Selling_Type__c = 'No Found';
        item.Selling_Unit_Price__c = 0;
        update item;
        
        item.Defective_Source__c = '原残';
        item.Inspect_QTY_D__c = 3;
        update item;
    }
}