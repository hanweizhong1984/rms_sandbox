@IsTest(isParallel=true)
public class Test_RTV_DeliveryPDF_Export {
    @IsTest
    private static void test() {
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
        
        ApexPages.currentPage().getParameters().put('summaryId', summary.Id);
        RTV_DeliveryPDF_Export ctrl = new RTV_DeliveryPDF_Export();
        
        ctrl.updateHaveReadDelivery();
        ctrl.test();
        System.debug(ctrl.orders);
        System.debug(ctrl.printType);
    }
}