@IsTest(isParallel=true)
public class Test_Trigger_RMS_Baozun_Seeding {
    @isTest
    public static void test() {
        RTV_Baozun_Seeding__c seeding1 = new RTV_Baozun_Seeding__c();
        seeding1.Year__c = 2021;
        seeding1.Month__c = 5;
        insert seeding1;

        RTV_Baozun_Seeding__c seeding2 = new RTV_Baozun_Seeding__c();
        seeding2.Year__c = 2021;
        seeding2.Month__c = 6;
        insert seeding2;

        seeding1.Status__c = 'In Process';
        update seeding1;

    }
}