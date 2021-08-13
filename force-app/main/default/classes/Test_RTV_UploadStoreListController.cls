@IsTest(isParallel=true)
public class Test_RTV_UploadStoreListController {
    @isTest
    public static void test() {
        
        // 创建soldto ~ shipto
        RMS_Account_Group__c acgroup = new RMS_Account_Group__c();
        acgroup.Name = '00)CC';
        insert acgroup;
        
        RMS_Sold_To__c soldto = new RMS_Sold_To__c();
        soldto.Name = '10003';
        soldto.Account_Group__c = acgroup.Id;
        insert soldto;
        
        RMS_Ship_To__c shipto = new RMS_Ship_To__c();
        shipto.Name = '10001';
        shipto.DTC_Code__c = '6002';
        shipto.Sold_To_Code__c = soldto.Id;
        shipto.IsDtcValid__c = true;
        insert shipto;
        
        // 创建program
        RTV_Program__c program = new RTV_Program__c();
        program.RecordTypeId = RMS_CommonUtil.getRecordTypes('RTV_Program__c').get('CFS DTC Takeback').Id;
        insert program;
        
        RTV_RP_Summary_Budget__c summaryBg = new RTV_RP_Summary_Budget__c();
        summaryBg.Return_Program__c = program.Id;
        summaryBg.Account_Group__c = acgroup.Id;
        summaryBg.Tack_Back_Net__c = 100;
        summaryBg.MSRP__c = 100;
        summaryBg.QTY__c = 100;
        insert summaryBg;
        
        RTV_RP_Ship_To__c shiptoWL = new RTV_RP_Ship_To__c();
        shiptoWL.Sold_To__c = soldto.Id;
        shiptoWL.Ship_To__c = shipto.Id;
        shiptoWL.RTV_Program__c = program.Id;
        shiptoWL.Summary_Budget__c = summaryBg.Id;  
        insert shiptoWL;
        
        // 创建ctrl
        ApexPages.currentPage().getParameters().put('id', program.Id);
        RTV_UploadStoreListController ctrl = new RTV_UploadStoreListController();
        ctrl.fileUploadName = 'xxxx';
        ctrl.getFileCharset();
        ctrl.setFileCharset('UTF-8');
        ctrl.uploadFile();
        
        // 无csv
        ctrl.uploadFile();
        
        // 错误csv
        ctrl.fileUploadBody = Blob.valueOf(
            'Store\r' +
            '8888\r'
        );
        ctrl.uploadFile();
        
        // 正常csv
        ctrl.fileUploadBody = Blob.valueOf(
            'Store\r' +
            shipto.DTC_Code__c + '\r'
        );
        ctrl.uploadFile();
        
        // 退出
        ctrl.cancel();
    }
}