@IsTest(isParallel=true)
public class Test_Trigger_RMS_Order_StatusChange_DEF {
    @isTest
    public static void test() {
        // defsummary
        RTV_DEF_Summary__c summary = new RTV_DEF_Summary__c();
        summary.Year__c = '2019';
        summary.Month__c = 12;
        insert summary;
        
        // 创建order
        RTV_Order__c order = new RTV_Order__c();
        order.RTV_DEF_Summary__c = summary.Id;
        order.Earliest_Delivery_Date__c = System.today();
        order.Ship_To_Contact__c = 'xx';
        order.Ship_To_Phone1__c = '13012341234';
        order.Ship_To_Phone2__c = '13012341234';
        order.Ship_To_Address__c = 'xx';
        order.Ship_To_Outbound_Emails__c = 'xx@xx.xx';
        order.Application_QTY__c = 123.45;
        order.Status__c = 'Ready';
        insert order;
        
        // update order
        order.Status__c = 'POST to LF';
        update order;
        
        // update order
        order.Insp_CS_Approve_Time__c = System.now();
        update order;
    }
}