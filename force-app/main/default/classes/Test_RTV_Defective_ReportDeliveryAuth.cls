@IsTest(isParallel=true)
public with sharing class Test_RTV_Defective_ReportDeliveryAuth {
    @IsTest
    private static void test(){

        RTV_Defective_ReportDeliveryAuth test = new RTV_Defective_ReportDeliveryAuth();

        String dateStr = test.SysDateStr;
    }
}