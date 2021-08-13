@IsTest(isParallel=true)
public class Test_RTV_DEF_Summary {
    @isTest
    public static void test() {
        RMS_Account_Group__c accgrp = new RMS_Account_Group__c();
        accgrp.Name = 'xx)xx';
        insert accgrp;
        
        RMS_Sold_To__c soldto = new RMS_Sold_To__c();
        soldto.Name = '12345';
        soldto.Account_Group__c = accgrp.Id;
        insert soldto;
        
        RMS_Ship_To__c shipto = new RMS_Ship_To__c();
        shipto.Name = '1234567';
        shipto.Sold_To_Code__c = soldto.Id;
        shipto.OwnerId = UserInfo.getUserId();
        insert shipto;
        
        RTV_DEF_Summary__c summary = new RTV_DEF_Summary__c();
        summary.Account_Group__c = accgrp.Id;
        summary.Year__c = '2021';
        summary.Month__c = 3;
        insert summary;
        
        RTV_Order__c order = new RTV_Order__c();
        order.RTV_DEF_Summary__c = summary.Id;
        order.Name = 'xxx';
        order.Status__c = 'Insp Wait Approval';
        insert order;
        
        // ----------------------------
        // 开始测试
        // ----------------------------
        RTV_DEF_Summary ctrl = new RTV_DEF_Summary(new ApexPages.StandardController(summary));
        
        ctrl.getLoginUser();
        ctrl.loadPage();
        Integer cnt = ctrl.orders_Cnt;
        
        ctrl.inbound();
        
        // ----------------------------
        // createOrderForm
        // ----------------------------
        ctrl.createOrderForm.open();
        ctrl.createOrderForm.close();
        System.debug(ctrl.CreateOrderForm.error);
        
        ctrl.createOrderForm.inputShipToCode = 'error';
        ctrl.createOrderForm.submit();
        
        ctrl.createOrderForm.inputShipToCode = '1234567';
        ctrl.createOrderForm.submit();
        
        ctrl.createOrderForm.inputShipToCode = '1234567';
        ctrl.createOrderForm.submit();
        
        // ----------------------------
        // ApprovalSubmitForm
        // ----------------------------
        ctrl.appSubmitForm.open();
        ctrl.appSubmitForm.close();
        
        ctrl.appSubmitForm.submit();
        
        ctrl.appSubmitForm.isSubmiterChecked = true;
        ctrl.appSubmitForm.submit();
        
        // ----------------------------
        // ApprovalForm
        // ----------------------------
        ctrl.approveForm.open();
        ctrl.approveForm.close();
        ctrl.approveForm.approve();
        ctrl.approveForm.reject();
        
        // ----------------------------
        // Tb2DefConfirmForm
        // ----------------------------
        ctrl.tb2defForm.open();
        ctrl.tb2defForm.close();
        ctrl.tb2defForm.approve();
    }
}