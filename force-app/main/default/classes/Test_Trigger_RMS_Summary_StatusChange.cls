@IsTest(isParallel=true)
public class Test_Trigger_RMS_Summary_StatusChange {
    @IsTest
    public static void test() {
        List<ConverseRMS__c> settings = [SELECT TaxRate__c FROM ConverseRMS__c LIMIT 1];
        if (settings.isEmpty()) {
            insert new ConverseRMS__c(ExRate__c = 1.13);
        }
        else if (settings[0].TaxRate__c == null) {
            update new ConverseRMS__c(Id=settings[0].Id, ExRate__c = 1.13);
        }
        
        RTV_Program__c program = new RTV_Program__c();
        insert program;
        
        RTV_Summary__c summary = new RTV_Summary__c();
        summary.RTV_Program__c = program.Id;
        summary.Status__c = 'Pending';
        summary.Inbound_Amount__c = 123.45;
        summary.Application_QTY__c = 123;
        insert summary;
        
        RTV_Order__c order = new RTV_Order__c();
        order.Return_Summary__c = summary.Id;
        order.Status__c = 'Pending';
        order.Earliest_Delivery_Date__c = System.today();
        order.Ship_To_Contact__c = 'xx';
        order.Ship_To_Phone1__c = '13012341234';
        order.Ship_To_Phone2__c = '13012341234';
        order.Ship_To_Address__c = 'xx';
        order.Application_QTY__c = 100;
        insert order;
        
        summary.Status__c = 'Remove';
        update summary;
        
        summary.Status__c = 'Ready';
        update summary;
        
        summary.Status__c = 'POST to LF';
        update summary;
        
        summary.Status__c = 'Completed';
        update summary;
        
        try {
            summary.Status__c = 'xxxxxxxxxxxxxxxxxxxxxxx';
            update summary;
        } catch(Exception err) {}
        
        summary.Summary_Type__c = 'DTC Takeback';
        summary.Status__c = 'Ready';
        update summary;
        summary.Status__c = 'POST to LF';
        update summary;
    }
}