@IsTest(isParallel=true)
public with sharing class Test_RTV_SummaryCtrl {
    @IsTest
    public static void test() {
        // program
        RTV_Program__c program = new RTV_Program__c();
        program.ExRate__c = 7.1;
        insert program;
        
        // summary
        RTV_Summary__c summary = new RTV_Summary__c();
        summary.Name = 'xxxx';
        summary.RTV_Program__c = program.Id;
        insert summary;
        
        // order
        RTV_Order__c order = new RTV_Order__c();
        order.Name = RMS_CommonUtil.order_getCode('xxx', 'xxxx', 'xxx');
        order.Return_Summary__c = summary.Id;
        insert order;
        
        // item
        RTV_Order_Item__c item = new RTV_Order_Item__c();
        item.RTV_Order__c = order.Id;
        item.Material_Code__c = 'PDT000001';
        item.BU_2__c = 'AP';
        item.Season_Code_CN__c = '20Q1';
        item.SKU_Size_US__c = 'XL';
        item.Selling_Unit_Price__c = 123.45;
        item.Inspect_QTY_A__c = 1;
        item.Inspect_QTY_B__c = 1;
        item.Inspect_QTY_C__c = 1;
        item.Inspect_QTY_D__c = 1;
        insert item;
        
        // 开始test
        RTV_SummaryCtrl ctrl = new RTV_SummaryCtrl(new ApexPages.StandardController(summary));
        ctrl.getLoginUser();
        ctrl.loadPage();
        System.debug(ctrl.summaryTotal.Actual_Amount_CNY);
        System.debug(ctrl.summaryTotal.Actual_Amount_CNY_inV);
        System.debug(ctrl.summaryTotal.Application_Amount_CNY);
        System.debug(ctrl.summaryTotal.Application_Amount_NET);
        System.debug(ctrl.summaryTotal.Application_QTY);
        System.debug(ctrl.summaryTotal.Inbound_QTY);
        System.debug(ctrl.summaryTotal.Inspect_QTY_A);
        System.debug(ctrl.summaryTotal.Inspect_QTY_B);
        System.debug(ctrl.summaryTotal.Inspect_QTY_C);
        System.debug(ctrl.summaryTotal.Inspect_QTY_D);
        System.debug(ctrl.orders_Cnt);
        
        // 修改recall
        ctrl.updateRecall();
        
        // 提交审批
        try { ctrl.approvalForm.open(); } catch(Exception err) {}
        ctrl.approvalForm.submit();
        ctrl.approvalForm.close();
        
        // complete
        ctrl.completeSummaryForm.open();
        ctrl.completeSummaryForm.submit();
        ctrl.completeSummaryForm.close();
    }
}