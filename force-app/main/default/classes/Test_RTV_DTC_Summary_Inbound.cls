@IsTest(isParallel=true)
public with sharing class Test_RTV_DTC_Summary_Inbound {
    @isTest
    public static void test() {
        // account group
        RMS_Account_Group__c acg = new RMS_Account_Group__c();
        acg.Name = '00)CC';
        insert acg;
        
        // soldto
        RMS_Sold_To__c soldto = new RMS_Sold_To__c();
        soldto.Name = 'xxxx';   
        soldto.Account_Group__c = acg.Id;
        insert soldto;
        
        // shipto
        RMS_Ship_To__c shipto = new RMS_Ship_To__c();
        shipto.Name = 'xxxxxxx';   
        shipto.Sold_To_Code__c = soldto.Id;
        insert shipto;
        
        // summary
        RTV_Summary__c summary = new RTV_Summary__c();
        summary.Account_Group__c = acg.Id;
        summary.Name = 'xxxx';
        insert summary;
        
        // order
        RTV_Order__c order = new RTV_Order__c();
        order.Return_Summary__c = summary.Id;
        order.Name = 'xxxxx';
        order.Sold_To__c = soldto.Id;
        order.Ship_To__c = shipto.Id;
        order.Status__c = 'Insp Confirmed';
        order.Inspect_QTY_C__c = 1;
        order.Inspect_QTY_D__c = 1;
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
        item.Inspect_QTY_D__c = 2;
        insert item;
        
        // -----------------------------
        // 开始test
        // -----------------------------
        ApexPages.currentPage().getParameters().put('summaryId', summary.Id);
        RTV_DTC_Summary_Inbound ctrl = new RTV_DTC_Summary_Inbound();
        ctrl.getLoginUser();
        
        // loadPage
        ctrl.loadPage();
        ctrl.cancel();
        System.debug(ctrl.deliveryDate);
        System.debug(ctrl.contentDocumentId);
        
        // ----------------------------
        // lf inbound ABD
        // ----------------------------
        //无附件
        ctrl.inbound();
        
        // 无comment
        ctrl.summary.LF_WH_Inbound_Comment__c = 'xxxx';
        ctrl.inbound();
        
        // 上传空附件
        ctrl.upload();
        
        // 上传附件LF_WH
        ctrl.summary.LF_WH_Inbound_Date__c = null;
        ctrl.fileBody = Blob.valueOf('xxxxx');
        ctrl.fileName = 'xxxxxx';
        ctrl.upload();
        
        // 上传附件CS
        ctrl.summary.LF_WH_Inbound_Date__c = System.today();
        ctrl.summary.CS_Inbound_Date__c = null;
        ctrl.fileBody = Blob.valueOf('xxxxx');
        ctrl.fileName = 'xxxxxx';
        ctrl.upload();
        
        // 上传附件LFDELY
        ctrl.summary.LF_WH_Inbound_Date__c = System.today();
        ctrl.summary.CS_Inbound_Date__c = System.today();
        ctrl.fileBody = Blob.valueOf('xxxxx');
        ctrl.fileName = 'xxxxxx';
        ctrl.upload();
        
        // lf inbound ABD (recall)
        ctrl.summary.LF_WH_Inbound_Comment__c = 'xxxx';
        ctrl.summary.Attach_User__c = 'LFWH';
        ctrl.summary.Recall__c = true;
        ctrl.inbound();
        
        // lf inbound ABD: 没有defsummary
        order.To_DEF_Order__c = null;
        update order;
        ctrl.summary.Recall__c = false;
        ctrl.inbound();
        
        // lf inbound ABD: defSummary
        RTV_DEF_Summary__c defSummary = new RTV_DEF_Summary__c();
        defSummary.Account_Group__c = acg.Id;
        defSummary.Year__c = String.valueOf(System.today().year());
        defSummary.Month__c = System.today().month();
        defSummary.TakeBack_From_Date__c = System.today().addDays(-10);
        defSummary.Takeback_Till_Date__c = System.today().addDays(10);
        insert defSummary;
        
        // lf inbound ABD
        Test.startTest();
        try {
            order.To_DEF_Order__c = null;
            update order;
            
            ctrl.summary.Recall__c = false;
            ctrl.inbound();
            System.debug(ctrl.loadingPercent);
            System.debug(ctrl.isBatchLoading);
        } finally {
            Test.stopTest();
            ctrl.isBatchEnd();
        }
        
        // 删除附件
        try {
            ctrl.contentDocumentId = [SELECT Id FROM ContentDocument LIMIT 1][0].Id;
            ctrl.deleteAttach();
        } catch(Exception err) {}
    }
}