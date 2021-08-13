@IsTest(isParallel=true)
public class Test_RMS_Home_MySubmitApproval {
    @isTest
    public static void test() {
        RTV_Summary__c summary = new RTV_Summary__c();
        summary.Status__c = 'POST to LF';
        insert summary;
        
        Approval.ProcessSubmitRequest req1 = new Approval.ProcessSubmitRequest();
        req1.setObjectId(summary.Id);
        req1.setComments('xx');
        Approval.process(req1);
        
        new RMS_Home_MySubmitApproval();
    }
}