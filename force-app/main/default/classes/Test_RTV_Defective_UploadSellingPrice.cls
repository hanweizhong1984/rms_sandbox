@IsTest(isParallel=true)
public class Test_RTV_Defective_UploadSellingPrice {
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
        RTV_Defective_UploadSellingPrice ctrl = new RTV_Defective_UploadSellingPrice();
        ctrl.upload();
        
        ctrl.fileUploadBody = Blob.valueof('\r' +
            'LF Order Auth Code,DEF Order Item ID,Selling Type,Selling Unit Price (CNY/excl.VAT)\r' +
            +item.LF_Order_Auth_Code__c+','+item.Id+',,123.55\r'
        );
        ctrl.fileUploadName = 'xxxx';
        ctrl.getFileCharset();
        ctrl.setFileCharset('UTF-8');
        ctrl.upload();
        
        ctrl.cancel();
    }
}