@IsTest(isParallel=true)
public class Test_RTV_DTC_DEF_Upload_Reason {
    @isTest
    public static void test() {
        RTV_Order__c order = new RTV_Order__c();
        order.Name = '[order1]';
        insert order;
        
        RTV_Order_Item__c item = new RTV_Order_Item__c();
        item.RTV_Order__c = order.Id;
        item.Name = 'xxx';
        item.POS_SKU__c = '[sku]';
        insert item;
        
        RTV_Order_Item_Def_Detail__c detail = new RTV_Order_Item_Def_Detail__c();
        detail.RTV_Order_Item__c = item.Id;
        detail.Detail_Number__c = 1;
        insert detail;
        
        // -----------------------
        // 测试
        // -----------------------
        ApexPages.currentPage().getParameters().put('orderId', order.Id);
        RTV_DTC_DEF_Upload_Reason ctrl = new RTV_DTC_DEF_Upload_Reason();
        ctrl.fileUploadName = 'xx';
        ctrl.setFileCharset('UTF-8');
        ctrl.getFileCharset();
        ctrl.cancel();
        ctrl.upload();
        
        ctrl.fileUploadBody = Blob.valueOf(
            '授权码,序号,POS SKU,货品号,尺寸(美码),退货理由(必填),原残/客残,备注\r' +
            '[#Err##],1,[sku],xx,xx,理由,原残,\r'+ 
            '[order1],1,[sku],xx,xx,,原残,\r' + 
            '[order1],1,[sku],xx,xx,鞋盒,原残,\r' +
            '[order1],1,[sku],xx,xx,鞋盒,原残,特批\r'
        );
        ctrl.upload();
        
        ctrl.fileUploadBody = Blob.valueOf(
            '授权码,序号,POS SKU,货品号,尺寸(美码),退货理由(必填),原残/客残,备注\r' +
            '[order1],1,[sku],xx,xx,理由,原残,\r'
        );
        ctrl.upload();
        
        // -----------------------
        // 上传特批附件
        // -----------------------
        ctrl.specialDef.inputFileBody = Blob.valueOf('xx');
        ctrl.specialDef.inputFileName = 'xx.txt';
        try { ctrl.specialDef.uploadFile(); }catch(Exception err){}
        try { ctrl.specialDef.deleteFile(); }catch(Exception err){}
    }
}