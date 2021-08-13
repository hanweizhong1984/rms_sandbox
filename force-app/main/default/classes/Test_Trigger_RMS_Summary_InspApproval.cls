@IsTest(isParallel=true)
public class Test_Trigger_RMS_Summary_InspApproval {
    @IsTest
    public static void test() {
        // program
        RTV_Program__c program = new RTV_Program__c();
        insert program;
        
        // summary
        RTV_Summary__c summary = new RTV_Summary__c();
        summary.RTV_Program__c = program.Id;
        insert summary;
        
        // order
        RTV_Order__c order = new RTV_Order__c();
        order.Return_Summary__c = summary.Id;
        insert order;
        
        summary.Insp_Submit_Time__c = System.now();
        update summary;
        
        summary.Insp_Final_Approve_Time__c = System.now();
        update summary;
        
        summary.Insp_Final_Reject_Time__c = System.now();
        update summary;
        
        summary.Insp_CS_Approve_Time__c = System.now();
        update summary;
        
        summary.Inspect_QTY_D__c = 123;
        update summary;
    }
}