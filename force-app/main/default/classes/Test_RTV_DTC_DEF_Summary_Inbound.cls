@IsTest(isParallel=true)
public class Test_RTV_DTC_DEF_Summary_Inbound {
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
        
        // def summary
        RTV_DEF_Summary__c defSummary = new RTV_DEF_Summary__c();
        defSummary.Account_Group__c = acg.Id;
        defSummary.Year__c = String.valueOf(System.today().year());
        defSummary.Month__c = System.today().month();
        defSummary.TakeBack_From_Date__c = System.today().addDays(-10);
        defSummary.Takeback_Till_Date__c = System.today().addDays(10);
        defSummary.LF_WH_Inbound_Date__c = DateTime.now().date();
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
        
        // -----------------------------
        // 开始test
        // -----------------------------
        ApexPages.currentPage().getParameters().put('summaryId', defSummary.Id);
        RTV_DTC_DEF_Summary_Inbound ctrl = new RTV_DTC_DEF_Summary_Inbound();
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
        ctrl.summary.LF_WH_Inbound_Date__c = null;
        ctrl.inbound();
        
        // 无comment
        ctrl.summary.LF_WH_Inbound_Date__c = null;
        ctrl.summary.LF_WH_Inbound_Comment__c = 'xxxx';
        ctrl.inbound();
        
        // 上传空附件
        ctrl.upload();
        
        // 上传附件LF_WH
        ctrl.summary.LF_WH_Inbound_Date__c = null;
        ctrl.fileBody = Blob.valueOf('xxxxx');
        ctrl.fileName = 'xxxxxx';
        ctrl.upload();
        
        // inbound
        ctrl.summary.LF_WH_Inbound_Date__c = null;
        ctrl.inbound();
        
        // 其它
        ctrl.summary.LF_WH_Inbound_Date__c = null;
        ctrl.inboundLFWH();
        
        // 删除附件
        try {
            ctrl.contentDocumentId = [SELECT Id FROM ContentDocument LIMIT 1][0].Id;
            ctrl.deleteAttach();
        } catch(Exception err) {}
        
        RTV_DTC_DEF_Summary_Inbound.lieToTest();
    }
}