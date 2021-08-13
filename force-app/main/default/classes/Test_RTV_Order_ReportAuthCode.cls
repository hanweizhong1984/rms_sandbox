@IsTest(isParallel=true)
public class Test_RTV_Order_ReportAuthCode {
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
        
        // order
        RTV_Order__c order = new RTV_Order__c();
        order.Return_Summary__c = summary.Id;
        order.Name = 'xxxxx';
        order.Status__c = 'Ready';
        insert order;
        
        // 开始测试
        ApexPages.currentPage().getParameters().put('summaryId', summary.Id);
        RTV_Order_ReportAuthCode ctrl = new RTV_Order_ReportAuthCode();
        ctrl.getCsvString();
    }
}