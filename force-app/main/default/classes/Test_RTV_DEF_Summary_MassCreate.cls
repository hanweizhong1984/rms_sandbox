@IsTest(isParallel=true)
public class Test_RTV_DEF_Summary_MassCreate {
    @isTest
    public static void test() {
        RMS_Account_Group__c acc = new RMS_Account_Group__c();
        insert acc;
        
        RTV_DEF_Summary_MassCreate ctrl = new RTV_DEF_Summary_MassCreate();
        ctrl.cancel();
        ctrl.massCreate();
        
        ctrl.inputYear = 2021;
        ctrl.inputMonthFrom = 1;
        ctrl.inputMonthTill = 1;
        ctrl.massCreate();
        ctrl.deleteNoOrderSummary();
    }
}