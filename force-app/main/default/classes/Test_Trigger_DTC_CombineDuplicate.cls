@IsTest
public with sharing class Test_Trigger_DTC_CombineDuplicate {
    @isTest
    public static void test() {
       RTV_Order__c order = new RTV_Order__c();
       order.Name = 'xxx';
       order.Order_Type__c = 'CFS DTC Takeback';
       insert order;
       List<RTV_Order_Item__c> itemList = new List<RTV_Order_Item__c>();
       RTV_Order_Item__c itemA =new RTV_Order_Item__c();
       itemA.RTV_Order__c = order.Id;
       itemA.POS_SKU__c ='10021090661S';
       itemA.Application_QTY__c = 1;

       itemList.add(itemA);

       RTV_Order_Item__c itemB =new RTV_Order_Item__c();
       itemB.RTV_Order__c = order.Id;
       itemB.POS_SKU__c ='10021090661S';
       itemB.Application_QTY__c = 1;

       itemList.add(itemB);

       insert itemList;

    }
}