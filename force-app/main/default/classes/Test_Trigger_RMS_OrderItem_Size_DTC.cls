@IsTest(isParallel=true)
public class Test_Trigger_RMS_OrderItem_Size_DTC {
    @IsTest
    public static void test() {
        
        RTV_Order__c order =new RTV_Order__c();
        order.Order_Type__c='CFS DTC Takeback';
        insert order;
        RTV_Order_Item__c item = new RTV_Order_Item__c();
        item.RTV_Order__c = order.Id;
        item.BU_2__c ='AP';
        item.SKU_Size_Asia__c='XXL';
        
        insert item;
    }
}