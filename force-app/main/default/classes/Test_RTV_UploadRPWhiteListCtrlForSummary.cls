@IsTest(isParallel=true)
public class Test_RTV_UploadRPWhiteListCtrlForSummary {
    @IsTest
    static void test() {
        // RMS_Product__c product = new RMS_Product__c();
        // product.Material_Code__c = '10018342-A03';
        // product.Season_Code_CN__c = '20Q1';
        // product.BUCN__c = 'APP';
        // product.MSRP__c = 123.45;
        // insert product;
        
        RMS_Account_Group__c acgroup = new RMS_Account_Group__c();
        insert acgroup;
        
        RMS_Sold_To__c soldto = new RMS_Sold_To__c();
        soldto.Account_Group__c = acgroup.Id;
        soldto.TT_FTW_EG__c = 0.7;
        soldto.TT_FW_Seasonal__c = 0.8;
        soldto.TT_APP_ACC__c = 0.9;
        insert soldto;
        
        RMS_Ship_To__c shipto = new RMS_Ship_To__c();
        shipto.Name = '100001';
        shipto.Sold_To_Code__c = soldto.Id;
        insert shipto;
        
        RMS_Ship_To__c shipto2 = new RMS_Ship_To__c();
        shipto2.Name = '100002';
        shipto2.Sold_To_Code__c = soldto.Id;
        insert shipto2;
        
        RTV_Program__c program = new RTV_Program__c();
        insert program;
        
        RTV_RP_Summary_Budget__c summaryBg = new RTV_RP_Summary_Budget__c();
        summaryBg.Return_Program__c = program.Id;
        summaryBg.Account_Group__c = acgroup.Id;
        summaryBg.Tack_Back_Net__c = 100;
        summaryBg.MSRP__c = 100;
        summaryBg.QTY__c = 100;
        insert summaryBg;
        
        RTV_Summary__c summary = new RTV_Summary__c();
        summary.RTV_Program__c = program.Id;
        summary.Account_Group__c = acgroup.Id;
        insert summary;
        
        ApexPages.currentPage().getParameters().put('summaryId', summary.Id);
        RTV_UploadRPWhiteListCtrlForSummary ctrl = new RTV_UploadRPWhiteListCtrlForSummary();
        ctrl.cancel();
        
        // 空文件
        ctrl.uploadFile();
        
        // 上传
        ctrl.fileUploadBody = Blob.valueof(
            'Ship To\r' + 
            shipto.Name + '\r' + 
            shipto2.Name + '\r'
        );
        ctrl.fileUploadName = 'xxxx';
        ctrl.getFileCharset();
        ctrl.setFileCharset('UTF-8');
        ctrl.uploadFile();
        
        // 上传更新
        ctrl.fileUploadBody = Blob.valueof(
            'Ship To\r' + 
            shipto2.Name + '\r'
        );
        ctrl.uploadFile();
        
        // 上传错误
        ctrl.fileUploadBody = Blob.valueof(
            'Ship To\r' + 
            'error\r'
        );
        ctrl.uploadFile();
    }
}