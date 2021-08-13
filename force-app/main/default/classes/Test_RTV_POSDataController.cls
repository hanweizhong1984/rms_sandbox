@IsTest(isParallel=true)
public class Test_RTV_POSDataController {
    @isTest
    public static void test() {
        RTV_POS_Data__c pos = new RTV_POS_Data__c();
        pos.Name = 'xx';
        insert pos;
        
        ApexPages.StandardSetController st = new ApexPages.StandardSetController(new List<RTV_POS_Data__c>{pos});
        RTV_POSDataController ctrl = new RTV_POSDataController(st);
        ctrl.cancel();
        ctrl.deleteData();
    }
}