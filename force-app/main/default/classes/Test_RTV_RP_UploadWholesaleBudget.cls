@IsTest(isParallel=true)
public class Test_RTV_RP_UploadWholesaleBudget {
    @isTest
    public static void test() {
        
        RMS_Account_Group__c acgroup = new RMS_Account_Group__c();
        acgroup.Name = '01)YY';
        insert acgroup;
        
        RMS_Account_Group__c acgroup2 = new RMS_Account_Group__c();
        acgroup2.Name = '02)BELLE';
        insert acgroup2;
        
        //创建program
        RTV_Program__c program = new RTV_Program__c();
        insert program;
        
        //Controller
        ApexPages.currentPage().getParameters().put('id', program.Id);
        RTV_RP_UploadWholesaleBudgetController ctrl = new RTV_RP_UploadWholesaleBudgetController();
        ctrl.cancel();
        
        //空文件 
        ctrl.uploadFile();
        
        //上传CSV内容
        ctrl.fileUploadBody = Blob.valueof(
            'Account Group,QTY,MSRP,$NET\r' + 
            '01)YY,123,123,123\r'+
            '02)BELLE,123,123,123\r'
        );
        ctrl.fileUploadName = 'xxxx';
        ctrl.getFileCharset();
        ctrl.setFileCharset('UTF-8');
        ctrl.uploadFile();
        
        //上传, 更新BELLE, 删除YY
        ctrl.fileUploadBody = Blob.valueof(
            'Account Group,QTY,MSRP,$NET\r' + 
            '02)BELLE,123,123,123\r'
        );
        ctrl.uploadFile();
        
        //上传error
        ctrl.fileUploadBody = Blob.valueof(
            'Account Group,QTY,MSRP,$NET\r' + 
            '01)YY,123,123,123\r'+
            '01)YY,123,123,123\r'+
            'error,123,123,123\r'
        );
        ctrl.uploadFile();
    }
}