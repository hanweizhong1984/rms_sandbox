@IsTest(isParallel=true)
public with sharing class Test_RTV_Order_ReportCustomerInfo {
    @IsTest
    private static void test() {
        new RTV_Order_ReportCustomerInfoCtrl();
    }
}