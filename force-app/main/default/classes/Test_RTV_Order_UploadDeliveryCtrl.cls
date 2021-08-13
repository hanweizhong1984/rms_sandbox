@IsTest(isParallel=true)
public class Test_RTV_Order_UploadDeliveryCtrl {
    @isTest
    public static void test() {
        RTV_Summary__c summary = new RTV_Summary__c();
        insert summary;
        
        RTV_Order__c order = new RTV_Order__c();
        order.Return_Summary__c = summary.Id;
        order.Status__c = 'POST to LF';
        insert order;
        
        RTV_LF_Order__c lfOrder = new RTV_LF_Order__c();
        lfOrder.LF_Order_Auth_Code__c = RMS_CommonUtil.order_getLFCode(order.Order_Auth_Code__c, 'FW');
        lfOrder.RTV_Order__c = order.Id;
        insert lfOrder;
        
        RTV_Order_UploadDeliveryCtrl ctrl = new RTV_Order_UploadDeliveryCtrl();
        ctrl.upload();
        ctrl.fileUploadBody = Blob.valueof(
            '\r' +
            '退货授权号,实收,差异,箱数,体积,Date-到货,Date-提货\r' + 
            lfOrder.LF_Order_Auth_Code__c + ',18,2,5,1.5,2020/11/24,2020/11/23\r' +
            'error' + ',18,2,5,1.5,2020/11/24,2020/11/23\r'
        );
        ctrl.fileUploadName = 'xxxx';
        ctrl.getFileCharset();
        ctrl.setFileCharset('UTF-8');
        ctrl.upload();
        ctrl.cancel();
        
        ApexPages.currentPage().getParameters().put('summaryId', summary.Id);
        RTV_Order_UploadDeliveryCtrl ctrl2 = new RTV_Order_UploadDeliveryCtrl();
        ctrl2.cancel();
    }
}