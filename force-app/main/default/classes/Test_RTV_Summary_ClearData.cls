@IsTest(isParallel=true)
public with sharing class Test_RTV_Summary_ClearData {
    @IsTest
    public static void test() {
        // account group
        RMS_Account_Group__c acg = new RMS_Account_Group__c();
        acg.Name = 'xxx';
        insert acg;
        
        // soldto
        RMS_Sold_To__c soldto = new RMS_Sold_To__c();
        soldto.Name = 'xxxx';   
        soldto.Account_Group__c = acg.Id;
        insert soldto;
        
        // shipto
        RMS_Ship_To__c shipto = new RMS_Ship_To__c();
        shipto.Name = 'xxxxxxx';   
        shipto.Sold_To_Code__c = soldto.Id;
        insert shipto;

        // Program
        RTV_Program__c program = new RTV_Program__c();
        program.Name = 'xxxx';
        insert program;

        // summary
        RTV_Summary__c summary = new RTV_Summary__c();
        summary.Account_Group__c = acg.Id;
        summary.Name = 'xxxx';
        summary.RTV_Program__c = program.Id;
        summary.Status__c = 'Pending';
        insert summary;

        // -----------------------------
        // 开始test
        // -----------------------------
        ApexPages.currentPage().getParameters().put('programId', program.Id);
        RTV_Summary_ClearData ctrl = new RTV_Summary_ClearData();

        ctrl.getLoginUser();
        ctrl.clearData();
        ctrl.cancel();
    }
}