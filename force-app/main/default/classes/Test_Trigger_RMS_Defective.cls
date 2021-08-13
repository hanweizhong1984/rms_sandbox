@IsTest(isParallel=true)
public class Test_Trigger_RMS_Defective {
    @IsTest
    static void test()
    {
        RTV_Defective__c def = new RTV_Defective__c();
        def.name = 'def';
        def.Type__c = 'FTW';
        def.Defective_Auth_Code__c = '111111';
        def.Start_Date__c = Date.today();
        def.End_Date__c = Date.today().addDays(20);
        insert def;

        RTV_DEF_Summary__c defsummary = new RTV_DEF_Summary__c();
        defsummary.Year__c = '2021';
        defsummary.Month__c = 4;
        insert defsummary;

        RTV_Order__c order = new RTV_Order__c();
        order.RTV_DEF_Summary__c = defsummary.id;
        order.Actual_Date_Of_WSL_Confirmed__c = Date.today().addDays(10);
        insert order;

        RTV_Order__c tborder = new RTV_Order__c();
        tborder.RTV_DEF_Summary__c = defsummary.id;
        tborder.From_TakeBack_Order__c = order.id;
        tborder.Actual_Date_Of_WSL_Inbound__c = Date.today().addDays(10);
        insert tborder;

        def.Status__c = 'Off Policy';
        def.Refresh__c = true;
        update def;

        RTV_Defective__c deftest = new RTV_Defective__c();
        deftest.Type__c = 'FTW';
        deftest.name = 'deftest';
        deftest.Defective_Auth_Code__c = '222222';
        deftest.Start_Date__c = Date.today();
        deftest.End_Date__c = Date.today().addDays(20);
        insert deftest;

        RTV_Defective__c acapdef = new RTV_Defective__c();
        acapdef.name = 'acapdef';
        acapdef.Type__c = 'ACCAPP';
        acapdef.Defective_Auth_Code__c = '333333';
        acapdef.Start_Date__c = Date.today().addDays(1);
        acapdef.End_Date__c = Date.today().addDays(21);
        insert acapdef;

        acapdef.Refresh__c = true;
        update acapdef;
    }
}