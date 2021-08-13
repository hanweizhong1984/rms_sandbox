@IsTest(isParallel=true)
public class Test_RTV_Defective_UploadDeliveryCtrl {
    @isTest
    public static void test() {
        RTV_DEF_Summary__c summary = new RTV_DEF_Summary__c();
        summary.Year__c = '2021';
        summary.Month__c = 3;
        insert summary;
        
        RTV_Order__c order = new RTV_Order__c();
        order.RTV_DEF_Summary__c = summary.Id;
        order.Order_Auth_Code__c = '[order1]';
        order.Status__c = 'POST to LF';
        insert order;
        
        RTV_LF_Order__c lfOrder = new RTV_LF_Order__c();
        lfOrder.LF_Order_Auth_Code__c = RMS_CommonUtil.order_getLFCode(order.Order_Auth_Code__c, 'FW');
        lfOrder.RTV_Order__c = order.Id;
        insert lfOrder;
        
        // --------------------------
        // 开始测试
        // --------------------------
        ApexPages.currentPage().getParameters().put('defSummaryId', summary.Id);
        RTV_Defective_UploadDeliveryCtrl ctrl = new RTV_Defective_UploadDeliveryCtrl();
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
        
        ApexPages.currentPage().getParameters().put('defSummaryId', summary.Id);
        RTV_Defective_UploadDeliveryCtrl ctrl2 = new RTV_Defective_UploadDeliveryCtrl();
        ctrl2.cancel();
    }
}