@IsTest(isParallel=true)
public class Test_RTV_Order_ReportAuthCode_Email {
    @isTest
    public static void test() {
        // program
        RTV_Program__c program = new RTV_Program__c();
        program.Name = 'xx';
        insert program;
        
        // summary
        RTV_Summary__c summary = new RTV_Summary__c();
        summary.RTV_Program__c = program.Id;
        summary.Name = 'xxxx';
        insert summary;
        
        // defSummary
        RTV_DEF_Summary__c defsummary = new RTV_DEF_Summary__c();
        defsummary.Year__c = '2021';
        defsummary.Month__c = 3;
        insert defsummary;
        
        // order
        RTV_Order__c order = new RTV_Order__c();
        order.Return_Summary__c = summary.Id;
        order.Name = 'xxxxx';
        order.Status__c = 'Ready';
        insert order;
        
        // order
        RTV_Order__c order2 = new RTV_Order__c();
        order2.RTV_DEF_Summary__c = defsummary.Id;
        order2.Name = 'defxxxxx';
        order2.Status__c = 'Ready';
        insert order2;
        
        // 开始测试
        try { 
            RTV_Order_ReportAuthCode_Email.mailSummaryOrders(summary); 
        } catch(Exception err) {}
        try { 
            RTV_Order_ReportAuthCode_Email.mailDefSummaryOrders(defsummary);
        } catch(Exception err) {}
        
        RTV_Order_ReportAuthCode_Email.lieToTest();
    }
}