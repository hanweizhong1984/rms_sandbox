@IsTest(isParallel=true)
public class Test_RTV_Order_ReportDeliveryAuth {
    @IsTest
    private static void test() {
        
        ApexPages.currentPage().getParameters().put('orderId', '000000354');
        RTV_Order_ReportDeliveryAuth ctrl = new RTV_Order_ReportDeliveryAuth();
        System.debug(RTV_Order_ReportDeliveryAuth.empty);
        System.debug(ctrl.SysDateStr);
        
        ApexPages.currentPage().getParameters().put('summaryId', '0000001');
        ctrl = new RTV_Order_ReportDeliveryAuth();
    }
}