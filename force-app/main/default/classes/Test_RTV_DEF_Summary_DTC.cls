@IsTest(isParallel=true)
public class Test_RTV_DEF_Summary_DTC {
    @isTest
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
        
        RTV_DEF_Summary__c summary = new RTV_DEF_Summary__c();
        summary.Account_Group__c = accgrp.Id;
        summary.Year__c = '2021';
        summary.Month__c = 3;
        insert summary;
        
        // ----------------------------
        // 开始测试
        // ----------------------------
        RTV_DEF_Summary_DTC ctrl = new RTV_DEF_Summary_DTC(new ApexPages.StandardController(summary));
        ctrl.getLoginUser();
        ctrl.loadPage();
        System.debug(ctrl.orders_Cnt);
        
        // ----------------------------
        // createOrderForm
        // ----------------------------
        ctrl.createOrderForm.open();
        ctrl.createOrderForm.close();
        System.debug(ctrl.CreateOrderForm.error);
        
        ctrl.summary.DTC_Type__c = 'CFS';
        ctrl.createOrderForm.inputStoreCode = shipto.DTC_Code__c;
        ctrl.createOrderForm.submit();
        
        ctrl.summary.DTC_Type__c = 'DIG';
        ctrl.createOrderForm.inputShipToCode = shipto.Name;
        ctrl.createOrderForm.submit();
        ctrl.createOrderForm.submit();
        
        ctrl.summary.DTC_Type__c = 'CFS';
        ctrl.createOrderForm.inputShipToCode = 'error';
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
    }
}