@IsTest(isParallel=true)
public with sharing class Test_RTV_OffPolicy_Export {
    @isTest
    public static void test() {
        RTV_Program__c program = new RTV_Program__c();
        insert program;
        
        RMS_Account_Group__c acg = new RMS_Account_Group__c();
        insert acg;
        
        ApexPages.currentPage().getParameters().put('id', program.Id);
        RTV_OffPolicy_Export ctrl = new RTV_OffPolicy_Export();
        ctrl.budget1 = null;
        ctrl.budget2 = null;
        ctrl.budget3 = null;
        ctrl.budget4 = null;
        ctrl.budget5 = null;
        ctrl.budget6 = null;
        ctrl.budget7 = null;
        ctrl.budget8 = null;
        ctrl.budget9 = null;
        ctrl.budget10 = null;
        ctrl.budget11 = null;
        ctrl.budget12 = null;
        ctrl.budget13 = null;
        ctrl.budget14 = null;
        ctrl.budget15 = null;
        ctrl.test();
        ctrl.getItems();
        
        for (Integer i=1; i<=13; i++) {
            RTV_RP_Summary_Budget__c sumBgt = new RTV_RP_Summary_Budget__c();
            sumBgt.Return_Program__c = program.Id;
            sumBgt.Account_Group__c = acg.Id;
            sumBgt.QTY__c = 10;
            sumBgt.MSRP__c = 100;
            sumBgt.Tack_Back_Net__c = 100;
            insert sumBgt;
            
            new RTV_OffPolicy_Export();
        }
    }
}