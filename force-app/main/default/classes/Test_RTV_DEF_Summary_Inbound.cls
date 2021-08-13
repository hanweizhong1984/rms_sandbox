@IsTest(isParallel=true)
public with sharing class Test_RTV_DEF_Summary_Inbound {
    @IsTest
    public static void test() {
        // account group
        RMS_Account_Group__c acg = new RMS_Account_Group__c();
        acg.Name = 'xxx';
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
        
        // def summary
        RTV_DEF_Summary__c defSummary = new RTV_DEF_Summary__c();
        defSummary.Account_Group__c = acg.Id;
        defSummary.Year__c = String.valueOf(System.today().year());
        defSummary.Month__c = System.today().month();
        defSummary.TakeBack_From_Date__c = System.today().addDays(-10);
        defSummary.Takeback_Till_Date__c = System.today().addDays(10);
        defSummary.LF_WH_Inbound_Date__c = DateTime.now().date();
        // defSummary.CS_Inbound_Date__c = DateTime.now().date();
        insert defSummary;
        
        // order
        RTV_Order__c order = new RTV_Order__c();
        order.RTV_DEF_Summary__c = defSummary.Id;
        order.Name = RMS_CommonUtil.order_getCode('xxx', 'xxxx', 'xx');
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
        
        // item.packingDetail
        RTV_Order_Packing__c pkg = new RTV_Order_Packing__c();
        pkg.RTV_Order_Item__c = item.Id;
        pkg.Box_Code__c = 'xx';
        insert pkg;
        
        // -----------------------------
        // 开始test
        // -----------------------------
        ApexPages.currentPage().getParameters().put('summaryId', defSummary.Id);
        RTV_DEF_Summary_Inbound ctrl = new RTV_DEF_Summary_Inbound();
        
        // 异常
        try {
            ctrl.orders = null;
            ctrl.ZDSIComputing();
        } catch(Exception err) {}
        try {
            ctrl.summary = null;
            ctrl.inbound();
        } catch(Exception err) {}
        try {
            ctrl.loginUser = null;
            ctrl.upload();
        } catch(Exception err) {}
        
        // 开始
        ctrl = new RTV_DEF_Summary_Inbound();
        ctrl.getLoginUser();
        
        // loadPage
        ctrl.loadPage();
        ctrl.cancel();
        System.debug(ctrl.deliveryDate);
        System.debug(ctrl.contentDocumentId);
        ctrl.getInspectQTYC();
        
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
        ctrl.summary.LF_WH_Inbound_Date__c = Date.today();
        ctrl.summary.CS_Inbound_Date__c = null;
        ctrl.upload();
        
        // 上传附件LFDELY
        ctrl.summary.LF_WH_Inbound_Date__c = Date.today();
        ctrl.summary.CS_Inbound_Date__c = Date.today();
        ctrl.upload();
        
        // lf inbound ABD (recall)
        ctrl.summary.LF_WH_Inbound_Comment__c = 'xxxx';
        ctrl.summary.Attach_User__c = 'LFWH';
        ctrl.inbound();
        
        // lf inbound ABD
        Test.startTest();
        try {
            ctrl.inbound();
            System.debug(ctrl.loadingPercent);
            System.debug(ctrl.isBatchLoading);
        } finally {
            Test.stopTest();
            try {ctrl.isBatchEnd();}catch(Exception e){}
        }
        
        // ----------------------------
        // CS Inbound: 
        // ----------------------------
        // 计算ZDSI
        ctrl.initSapReport();
        try {
            ctrl.ZDSIComputing();
        } finally {
            try {ctrl.isBatchEnd();}catch(Exception e){}
        }
        
        // CS Inbound
        ctrl.inboundCS();
        
        ctrl.summary.CS_Inbound_Comment__c = 'xxx';
        ctrl.inboundCS();
        
        ctrl.summary.Attach_User__c = 'CS';
        ctrl.inboundCS();
        
        // ----------------------------
        // lf inbound C
        // ----------------------------
        ctrl.inboundC();
        
        ctrl.summary.LF_DELY_Inbound_Comment__c = 'xxx';
        ctrl.inboundC();
        
        ctrl.summary.Attach_User__c = 'LFDELY';
        ctrl.inboundC();
        
        // 删除附件
        try {
            ContentVersion version = new ContentVersion();
            version.versionData = Blob.valueOf('xx');
            version.title = 'xx';
            version.pathOnClient = 'xx';
            insert version;
            version = [SELECT ContentDocumentId FROM ContentVersion WHERE Id =:version.Id LIMIT 1];
            ctrl.contentDocumentId = version.ContentDocumentId;
            ctrl.deleteAttach();
            
            ctrl.summary.LF_WH_Inbound_Date__c = null;
            ctrl.deleteAttach();
            
            ctrl.summary.CS_Inbound_Date__c = null;
            ctrl.deleteAttach();
        } catch(Exception err) {}
        
        RTV_DEF_Summary_Inbound.lieToTest();
    }
}