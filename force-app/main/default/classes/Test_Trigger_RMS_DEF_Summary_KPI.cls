@IsTest(isParallel=true)
public class Test_Trigger_RMS_DEF_Summary_KPI {
    @IsTest
    static void test()
    {
        RTV_DEF_Summary__c defsummary = new RTV_DEF_Summary__c();
        defsummary.Year__c = '2021';
        defsummary.Month__c = 4;
        insert defsummary;
        
        RTV_Order__c order = new RTV_Order__c();
        order.Status__c = 'Ready';
        order.RTV_DEF_Summary__c = defsummary.id;
        order.Application_QTY__c = 1;
        order.Ship_To_Contact__c = 'x';
        order.Ship_To_Phone1__c = '13012345678';
        order.Ship_To_Address__c = 'x';
        order.Ship_To_Outbound_Emails__c = 'xx@xx.xx';
        order.Earliest_Delivery_Date__c = System.today().addDays(5);
        insert order;

        order.Status__c = 'POST to LF';
        update order;

        order.Status__c = 'Delivered';
        update order;

        order.Status__c = 'Inspected';
        update order;

        order.Status__c = 'Insp Wait Approval';
        update order;

        order.Status__c = 'Insp Confirmed';
        update order;

        order.Status__c = 'Inbound';
        update order;
    }
}