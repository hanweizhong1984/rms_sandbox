@IsTest
public with sharing class Test_RTV_Sch_OrderItem_getBudget {
  @isTest
  public static void test() {
    Test.StartTest();
    RTV_Sch_OrderItem_getBudget.lieToTest();
    RTV_OrderItem_getBudget.lieToTest();
    BudgetAggregateBatch.lieToTest();
    SearchResultIterable.lieToTest();
    SearchResultIterator.lieToTest();
    RMS_Ship_To__c shipto = new RMS_Ship_To__c();
    shipto.Name = '104429';
    shipto.DTC_Code__c = '6001';
    insert shipto;

    RTV_RP_Ship_To__c whiteshipto = new RTV_RP_Ship_To__c();
    whiteshipto.Ship_To__c = shipto.Id;
    insert whiteshipto;

    RMS_Product__c product = new RMS_Product__c();
    product.SKU__c = '10022855102';
    product.Material_Code__c = '10022855-A02';
    insert product;

    RTV_Program__c program = new RTV_Program__c();
    program.Name = 'cfstest';
    insert program;

    RTV_Summary__c summary = new RTV_Summary__c();
    summary.RTV_Program__c = program.Id;
    insert summary;

    RTV_Order__c order = new RTV_Order__c();
    order.Order_Type__c = 'CFS DTC Takeback';
    order.Return_Summary__c = summary.Id;
    order.Ship_To__c = shipto.Id;
    insert order;

    RTV_RP_Sku_Budget__c skubudget = new RTV_RP_SKU_Budget__c();
    skubudget.Return_Program__c = program.Id;
    skubudget.SKU_Material_Code__c = '10022855-A02';
    skubudget.RP_Ship_To__c = whiteshipto.Id;
    skubudget.Size__c = 'XXL';
    insert skubudget;

    RTV_Order_Item__c item = new RTV_Order_Item__c();
    item.RTV_Order__c = order.Id;
    item.Material_Code__c = '10022855102';
    item.BU_2__c = 'AP';
    item.SKU_Size_Asia__c = 'XXL';
    insert item;
    RTV_Sch_OrderItem_getBudget p = new RTV_Sch_OrderItem_getBudget();
    String sch = '0 30 15 26 4 ?';
    system.schedule('Test schexample', sch, p);
    Test.stopTest();
  }
}
