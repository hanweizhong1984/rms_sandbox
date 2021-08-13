@IsTest(isParallel=true)
public class Test_RTV_SummaryCtrl_DTC {
    @IsTest
    public static void test() {
        RMS_Account_Group__c accgrp = new RMS_Account_Group__c();
        accgrp.Name = '00)CC';
        insert accgrp;
        
        RMS_Sold_To__c soldto = new RMS_Sold_To__c();
        soldto.Name = '12345';
        soldto.Account_Group__c = accgrp.Id;
        insert soldto;
        
        RMS_Ship_To__c shipto = new RMS_Ship_To__c();
        shipto.Name = '1234567';
        shipto.DTC_Code__c = '1001';
        shipto.Sold_To_Code__c = soldto.Id;
        shipto.OwnerId = UserInfo.getUserId();
        shipto.IsDtcValid__c = true;
        insert shipto;
        
        // program
        RTV_Program__c program = new RTV_Program__c();
        program.ExRate__c = 7.1;
        insert program;
        
        // summary
        RTV_Summary__c summary = new RTV_Summary__c();
        summary.Name = 'xxxx';
        summary.Account_Group__c = accgrp.Id;
        summary.RTV_Program__c = program.Id;
        insert summary;
        
        // order
        RTV_Order__c order = new RTV_Order__c();
        order.Name = RMS_CommonUtil.order_getCode('xxx', 'xxxx', 'xxx');
        order.Return_Summary__c = summary.Id;
        order.Status__c = 'Insp Wait Approval';
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
        
        // ----------------------------
        // 开始test
        // ----------------------------
        RTV_SummaryCtrl_DTC ctrl = new RTV_SummaryCtrl_DTC(new ApexPages.StandardController(summary));
        ctrl.getLoginUser();
        ctrl.loadPage();
        System.debug(ctrl.orders_Cnt);
        System.debug(ctrl.summaryTotal.Application_QTY);
        System.debug(ctrl.summaryTotal.Inbound_QTY);
        System.debug(ctrl.summaryTotal.Inspect_QTY_A);
        System.debug(ctrl.summaryTotal.Inspect_QTY_B);
        System.debug(ctrl.summaryTotal.Inspect_QTY_C);
        System.debug(ctrl.summaryTotal.Inspect_QTY_D);
        
        // ----------------------------
        // 修改recall
        // ----------------------------
        ctrl.updateRecall();
        
        // ----------------------------
        // createOrderForm
        // ----------------------------
        ctrl.createOrderForm.open();
        ctrl.createOrderForm.close();
        System.debug(ctrl.CreateOrderForm.error);
        
        ctrl.createOrderForm.inputStoreCode = shipto.DTC_Code__c;
        ctrl.createOrderForm.submit();
        
        ctrl.createOrderForm.inputShipToCode = shipto.Name;
        ctrl.createOrderForm.submit();
        ctrl.createOrderForm.submit();
        
        ctrl.createOrderForm.inputShipToCode = 'error';
        ctrl.createOrderForm.submit();
        
        // ----------------------------
        // ApprovalSubmitForm
        // ----------------------------
        System.debug(ctrl.appSubmitForm.error);
        ctrl.appSubmitForm.open();
        ctrl.appSubmitForm.close();
        ctrl.appSubmitForm.submit();
        ctrl.appSubmitForm.isSubmiterChecked = true;
        ctrl.appSubmitForm.submit();
        
        // ----------------------------
        // ApprovalForm
        // ----------------------------
        System.debug(ctrl.approveForm.error);
        ctrl.approveForm.open();
        ctrl.approveForm.close();
        ctrl.approveForm.approve();
        ctrl.approveForm.reject();
    }
}