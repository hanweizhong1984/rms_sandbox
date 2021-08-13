@IsTest(isParallel=true)
public class Test_RTV_Baozun_Order_Inbound {
    @isTest
    public static void test() {
        RTV_Baozun_Seeding__c baozun = new RTV_Baozun_Seeding__c();
        baozun.Year__c = 2021;
        baozun.Month__c = 1;
        insert baozun;
        
        RTV_Order__c order = new RTV_Order__c();
        order.Name = 'xxx';
        order.RTV_Baozun_Seeding__c = baozun.Id;
        insert order;
        
        ApexPages.currentPage().getParameters().put('id', order.Id);
        RTV_Baozun_Order_Inbound ctrl = new RTV_Baozun_Order_Inbound();
        ctrl.cancel();
        
        ctrl.upload();
        ctrl.fileBody = Blob.valueOf('xxxxxxxxxxxxx');
        ctrl.fileName = 'xxxx';
        try {ctrl.upload();} catch(Exception err) {}
        
        ctrl.inbound();
    }
}