@IsTest(isParallel=true)
public class Test_RTV_OrderItem_ZDSI_Batch {
    @isTest
    public static void test() {
        // setting
        List<ConverseRMS__c> settings = [SELECT TaxRate__c FROM ConverseRMS__c LIMIT 1];
        if (settings.isEmpty()) {
            insert new ConverseRMS__c(TaxRate__c = 1.13);
        }
        else if (settings[0].TaxRate__c == null) {
            update new ConverseRMS__c(Id=settings[0].Id, TaxRate__c = 1.13);
        }
        
        // product
        if ([
            SELECT Material_Code__c FROM RMS_Product__c
            WHERE Material_Code__c = 'PDT000001'
        ].isEmpty()) {
            RMS_Product__c pdt = new RMS_Product__c();
            pdt.Name = 'PDT000001_SP20';
            pdt.Material_Code__c = 'PDT000001';
            pdt.Season_Code_CN__c= '20Q1';
            pdt.Season_Code__c = 'SP20';
            pdt.MSRP__c = 213.55;
            insert pdt;
        }
        
        RTV_Order__c order = new RTV_Order__c();
        insert order;
        
        RTV_Order_Item__c item = new RTV_Order_Item__c();
        item.RTV_Order__c = order.Id;
        item.Material_Code__c = 'PDT000001';
        item.BU_2__c = 'AP';
        item.Season_Code_CN__c = '20Q1';
        item.SKU_Size_US__c = 'XL';
        item.Selling_Unit_Price__c = 123.45;
        insert item;
        
        item = new RTV_Order_Item__c();
        item.RTV_Order__c = order.Id;
        item.Material_Code__c = 'PDT000001';
        item.BU_2__c = 'AP';
        item.Season_Code_CN__c = '20Q1';
        item.SKU_Size_US__c = 'XL';
        item.Selling_Unit_Price__c = 456.45;
        insert item;
        
        // PS：测试batch需要 Test.StartTest() 和 Test.StopTest()
        Test.StartTest();
        Database.executeBatch(new RTV_OrderItem_ZDSI_Batch(new List<Id>{order.Id}));
        Test.StopTest();
    }
}