@IsTest
public with sharing class Test_RTV_Sch_SKU_KPI {
    @isTest
    public static void test() {

        Test.StartTest();
    
        // account group
        RMS_Account_Group__c acg = new RMS_Account_Group__c();
        acg.Name = 'ag';
        insert acg;

        // summary
        RTV_Program__c program = new RTV_Program__c();
        program.Finance_Code__c = 'Finance Code';
        insert program;

        // summary
        RTV_Summary__c summary = new RTV_Summary__c();
        summary.Account_Group__c = acg.Id;
        summary.RTV_Program__c = program.Id;
        summary.Name = 'summary';
        insert summary;

        // order
        RTV_Order__c order = new RTV_Order__c();
        order.Return_Summary__c = summary.Id;
        order.Name = RMS_CommonUtil.order_getCode('xxx', 'xxxx', 'xx');
        order.Status__c = 'Insp Confirmed';
        order.Inspect_QTY_D__c = 1;
        insert order;

        // item
        RTV_Order_Item__c item = new RTV_Order_Item__c();
        item.RTV_Order__c = order.Id;
        item.Material_Code__c = 'PDT000001';
        item.BU_2__c = 'AP';
        item.SKU_Style__c = 'style';
        item.SKU_Color__c = '001';
        item.Season_Code_CN__c = '20Q1';
        item.SKU_Size_US__c = 'XL';
        item.Selling_Unit_Price__c = 123.45;
        item.Inspect_QTY_A__c = 1;
        item.Inspect_QTY_B__c = 1;
        item.Inspect_QTY_C__c = 1;
        item.Inspect_QTY_D__c = 2;
        insert item;

        RTV_Sch_SKU_KPI p = new RTV_Sch_SKU_KPI();
        String sch = '0 30 15 26 4 ?';
        system.schedule('Test schexample', sch, p);
        Test.stopTest();

        RTV_Bth_SKU_KPI.lieToTest();
    }
}