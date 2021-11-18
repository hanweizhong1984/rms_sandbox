@IsTest(isParallel=true)
public with sharing class Test_RTV_RP_UploadSKUBudget {
    @isTest
    public static void test() {
        RMS_Product__c product = new RMS_Product__c();
        product.Material_Code__c = '00168C035';
        insert product;
        
        RMS_Product__c product2 = new RMS_Product__c();
        product2.Material_Code__c = '00168C035_rebuy';
        product2.CFS_Rebuy__c = 'Rebuy';
        insert product2;
        
        RMS_Account_Group__c acgroup = new RMS_Account_Group__c();
        acgroup.Name = 'xx)xx';
        insert acgroup;
        
        RMS_Sold_To__c soldto = new RMS_Sold_To__c();
        soldto.Name = 'xxxxxxx';
        soldto.Account_Group__c = acgroup.Id;
        insert soldto;
        
        RMS_Ship_To__c shipto = new RMS_Ship_To__c();
        shipto.Name = 'xxxxxxxxxxx';
        shipto.Sold_To_Code__c = soldto.Id;
        insert shipto;
        
        //创建program
        RTV_Program__c program = new RTV_Program__c();
        program.Finance_Code__c = 'xxx';
        insert program;
        
        //Controller
        ApexPages.currentPage().getParameters().put('id', program.Id);
        ApexPages.currentPage().getParameters().put('isGold', 'true');
        RTV_RP_UploadSKUBudgetController ctrl = new RTV_RP_UploadSKUBudgetController();
        ctrl.cancel();
        ctrl.checkResult();
        
        Test.StartTest();
        try {
            // 上传:空文件
            try { ctrl.uploadFile(); } catch (Exception err) {}
            
            // 上传:soldto级别
            ctrl.fileUploadBody = Blob.valueof(
                'SKU,Account Group,Sold To,Ship To,QTY,MSRP,$NET,order season\r'+
                '00168C035,,,,0,0,0,21Q2\r'+ 
                '00168C035_rebuy,,,,0,0,0,21Q2\r'+ 
                'error,,,,0,0,0,21Q2\r'
            );
            ctrl.fileUploadName = 'xxxx';
            ctrl.setFileCharset('UTF-8');
            ctrl.getFileCharset();
            try { ctrl.uploadFile(); } catch (Exception err) {}
            ctrl.checkResult();
            ctrl.getIsLoading();
            System.debug(ctrl.batchPercent);
            
            // accountGroup级别
            ctrl.fileUploadBody = Blob.valueof(
                'SKU,Account Group,Sold To,Ship To,QTY,MSRP,$NET,order season\r'+
                '00168C035,' + acgroup.Name + ',,,0,0,0,21Q2\r'
            );
            ctrl.uploadFile();
            
            // soldto级别
            ctrl.fileUploadBody = Blob.valueof(
                'SKU,Account Group,Sold To,Ship To,QTY,MSRP,$NET,order season\r'+
                '00168C035,,' + soldto.Name + ',,0,0,0,21Q2\r'
            );
            ctrl.uploadFile();
            
            // shipto级别
            ctrl.fileUploadBody = Blob.valueof(
                'SKU,Account Group,Sold To,Ship To,QTY,MSRP,$NET,order season\r'+
                '00168C035,,,' + shipto.Name + ',0,0,0,21Q2\r'
            );
            ctrl.uploadFile();
        } finally {
            Test.StopTest();
            ctrl.checkResult();
        }
    }
}