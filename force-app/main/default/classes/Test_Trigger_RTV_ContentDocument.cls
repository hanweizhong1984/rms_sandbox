@IsTest(isParallel=true)
public with sharing class Test_Trigger_RTV_ContentDocument {
    @IsTest
    public static void test() {
        // account group
        RMS_Account_Group__c acg = new RMS_Account_Group__c();
        acg.Name = 'xxx';
        insert acg;

        // def summary
        RTV_DEF_Summary__c defSummary = new RTV_DEF_Summary__c();
        defSummary.Account_Group__c = acg.Id;
        defSummary.Year__c = String.valueOf(System.today().year());
        defSummary.Month__c = System.today().month();
        defSummary.TakeBack_From_Date__c = System.today().addDays(-10);
        defSummary.Takeback_Till_Date__c = System.today().addDays(10);
        insert defSummary;

        ContentVersion v = new ContentVersion();
        v.versionData = Blob.valueof('Summary Attachment...');
        v.title = 'fileName';
        v.pathOnClient = 'fileName';
        insert v;
        ContentVersion cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id =:v.Id LIMIT 1];
        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.LinkedEntityId = defSummary.Id;
        cdl.ContentDocumentId= cv.ContentDocumentId;
        cdl.ShareType= 'I';
        insert cdl;

        ContentDocument cd = [SELECT Id, Title FROM ContentDocument WHERE Id= :cv.ContentDocumentId LIMIT 1];
        try {delete cd;} catch(Exception e){}
    }
}