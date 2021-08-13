@IsTest(isParallel=true)
public class Test_Trigger_RMS_Order_Total {
    @IsTest
    public static void test() {
        RMS_Account_Group__c grp = new RMS_Account_Group__c();
        insert grp;
        
        RTV_Program__c program = new RTV_Program__c();
        insert program;
        
        RTV_RP_Summary_Budget__c budget = new RTV_RP_Summary_Budget__c();
        budget.Return_Program__c = program.Id;
        budget.Account_Group__c = grp.Id;
        budget.QTY__c = 123;
        budget.Tack_Back_Net__c = 123;
        insert budget;
        
        RTV_Summary__c summary = new RTV_Summary__c();
        summary.Status__c = 'Ready';
        summary.Summary_Budget__c = budget.Id;
        insert summary;
        
        RTV_Order__c order = new RTV_Order__c();
        order.Return_Summary__c = summary.Id;
        order.Status__c = 'Ready';
        
        order.Application_QTY__c = 10;
        order.Application_Amount__c = 10;
        insert order;
        
        try {
            order.Application_QTY__c = 456;
            update order;
        } catch(Exception err) {}
        
        
        try {
            order.Application_Amount__c = 456;
            update order;
        } catch(Exception err) {}
        
        delete order;
    }
}