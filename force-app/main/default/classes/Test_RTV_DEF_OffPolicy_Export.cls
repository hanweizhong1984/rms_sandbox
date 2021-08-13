@IsTest(isParallel=true)
public with sharing class Test_RTV_DEF_OffPolicy_Export {
    @IsTest
    static void test()
    {
        
        RTV_Defective__c program = new RTV_Defective__c();
        program.name = 'program';
        program.Type__c = 'FTW';
        program.Start_Date__c = Date.today();
        program.End_Date__c = Date.today().addDays(20);
        insert program;
        Apexpages.currentPage().getParameters().put('id', program.id);
        new RTV_DEF_OffPolicy_Export();

        RTV_DEF_Expected_Result__c result = new RTV_DEF_Expected_Result__c();
        result.RTV_DEF_Program__c = program.id;
        result.Return_Product_Descripton__c = 'aaabbbccc';
        result.Total_Units__c = 111;
        result.Original_Wholesale_Price__c = 111;
        result.Landing_Cost__c = 111;
        result.P_L_Impact__c = 111;
        result.Estimated_claim_from_factory__c = 111;
        insert result;

        new RTV_DEF_OffPolicy_Export();
        RTV_DEF_Expected_Result__c result1 = new RTV_DEF_Expected_Result__c();
        result1.RTV_DEF_Program__c = program.id;
        result1.Return_Product_Descripton__c = 'aaabbbccc';
        result1.Total_Units__c = 111;
        result1.Original_Wholesale_Price__c = 111;
        result1.Landing_Cost__c = 111;
        result1.P_L_Impact__c = 111;
        result1.Estimated_claim_from_factory__c = 111;
        insert result1;

        new RTV_DEF_OffPolicy_Export();

        RTV_DEF_Expected_Result__c result2 = new RTV_DEF_Expected_Result__c();
        result2.RTV_DEF_Program__c = program.id;
        result2.Return_Product_Descripton__c = 'aaabbbccc';
        result2.Total_Units__c = 111;
        result2.Original_Wholesale_Price__c = 111;
        result2.Landing_Cost__c = 111;
        result2.P_L_Impact__c = 111;
        result2.Estimated_claim_from_factory__c = 111;
        insert result2;

        new RTV_DEF_OffPolicy_Export();   
    }
}