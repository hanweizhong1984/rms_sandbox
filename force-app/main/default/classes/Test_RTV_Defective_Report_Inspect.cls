@IsTest(isParallel=true)
public with sharing class Test_RTV_Defective_Report_Inspect {
    @IsTest
    private static void test(){
        RTV_Defective_Report_Inspect ctrl = new RTV_Defective_Report_Inspect();
        System.debug(RTV_Defective_Report_Inspect.empty);
    }
}