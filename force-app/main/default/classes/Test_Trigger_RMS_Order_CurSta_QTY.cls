@IsTest(isParallel=true)
public class Test_Trigger_RMS_Order_CurSta_QTY {
    @IsTest
    public static void test() {
        RTV_Summary__c summary = new RTV_Summary__c();
        insert summary;

        RTV_Order__c order = new RTV_Order__c();
        order.Return_Summary__c = summary.Id;
        order.Name = 'xxx';
        order.Status__c = 'Ready';
        order.Earliest_Delivery_Date__c = System.today();
        order.Ship_To_Contact__c = 'xx';
        order.Ship_To_Phone1__c = '13012345678';
        order.Ship_To_Address__c = 'xx';
        order.Application_QTY__c = 111;
        order.Delivery_QTY__c = 111;
        order.Inspect_QTY_A__c = 111;
        order.Inspect_QTY_B__c = 111;
        order.Inspect_QTY_C__c = 111;
        order.Inspect_QTY_D__c = 111;
        insert order;

        order.Status__c = 'POST to LF';
        order.Application_QTY__c = 222;
        update order;

        order.Status__c = 'Delivered';
        order.Delivery_QTY__c = 222;
        update order;

        order.Status__c = 'Inspected';
        order.Inspect_QTY_A__c = 222;
        order.Inspect_QTY_B__c = 222;
        order.Inspect_QTY_C__c = 222;
        order.Inspect_QTY_D__c = 222;
        update order;

        order.Status__c = 'Completed';
        update order;

    }
}