@IsTest(isParallel=true)
public class Test_RTV_Order_UploadSellingPrice {
    @isTest
    public static void test() {
        RTV_Order__c order = new RTV_Order__c();
        order.Status__c = 'Insp Wait Approval';
        order.Name = RMS_CommonUtil.order_getCode('xxx', '01)xx', 'xxx');
        insert order;
        
        RTV_Order_Item__c item = new RTV_Order_Item__c();
        item.RTV_Order__c = order.Id;
        item.Material_Code__c = 'PDT000001';
        item.BU_2__c = 'AP';
        item.Season_Code_CN__c = '20Q1';
        item.SKU_Size_US__c = 'XL';
        insert item;
        item = [SELECT LF_Order_Auth_Code__c FROM RTV_Order_Item__c WHERE id = :item.Id];
        
        // --------------------
        // 开始test
        // --------------------
        RTV_Order_UploadSellingPriceCtrl ctrl = new RTV_Order_UploadSellingPriceCtrl();
        ctrl.upload();
        
        ctrl.fileUploadBody = Blob.valueof('\r' +
            'LF Order Auth Code,BU,Material Code,Size (US),Season Code (CN),Selling Type,Selling Unit Price (CNY/excl.VAT)\r' +
            + item.LF_Order_Auth_Code__c + ',AP,PDT000001,XL,20Q1,,123.55\r'
        );
        ctrl.fileUploadName = 'xxxx';
        ctrl.getFileCharset();
        ctrl.setFileCharset('UTF-8');
        ctrl.upload();
        
        ctrl.cancel();
    }
}