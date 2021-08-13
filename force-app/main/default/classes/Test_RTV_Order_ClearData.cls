@IsTest(isParallel=true)
public with sharing class Test_RTV_Order_ClearData {
    @isTest
    public static void test() {
        // defSummary
        // defSummary
        RTV_DEF_Summary__c defsummary = new RTV_DEF_Summary__c();
        defsummary.Year__c = '2021';
        defsummary.Month__c = 3;
        insert defsummary;
        
        // summary
        RTV_Summary__c summary = new RTV_Summary__c();
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
        RTV_Order_ClearData ctrl = new RTV_Order_ClearData();
        ctrl.loadPage();
        ctrl.getLoginUser();
        ctrl.cancel();
        ctrl.clearData();
        
        // 开始测试
        ApexPages.currentPage().getParameters().put('defSummaryId', defSummary.Id);
        ctrl = new RTV_Order_ClearData();
        ctrl.loadPage();
        ctrl.clearData();
    }
}