@IsTest(isParallel=true)
public class Test_Trigger_RMS_Order_DEFDetail_Total {
    @isTest
    public static void test() {
        // 创建order
        RTV_Order__c order = new RTV_Order__c();
        order.Status__c = 'Ready';
        insert order;
        
        // 创建item
        RTV_Order_Item__c item = new RTV_Order_Item__c();
        item.RTV_Order__c = order.Id;
        item.Material_Code__c = 'xxxx';
        insert item;
        
        // detail
        RTV_Order_Item_DEF_Detail__c detail = new RTV_Order_Item_DEF_Detail__c();
        detail.RTV_Order_Item__c = item.Id;
        insert detail;
        
        // update detail
        detail.Acceptable_Return_QTY__c = 1;
        detail.Reject_QTY__c = 1;
        update detail;
    }
}