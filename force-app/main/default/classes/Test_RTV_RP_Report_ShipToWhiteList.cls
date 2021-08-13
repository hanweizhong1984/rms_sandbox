@IsTest(isParallel=true)
public with sharing class Test_RTV_RP_Report_ShipToWhiteList {
    @IsTest
    public static void test() {
        RTV_Program__c program = new RTV_Program__c();
        insert program;
        
        RTV_Summary__c summary = new RTV_Summary__c();
        insert summary;
        
        ApexPages.currentPage().getParameters().put('programId', program.Id);
        RTV_RP_Report_ShipToWhiteList ctrl = new RTV_RP_Report_ShipToWhiteList();

        ApexPages.currentPage().getParameters().put('summaryId', summary.Id);
        ctrl = new RTV_RP_Report_ShipToWhiteList();
    }
}