@IsTest(isParallel=true)
public  class Test_Trigger_RMS_Summary_Date_Compute {
    @IsTest
    public static void test() {
        RTV_Program__c program = new RTV_Program__c();
        insert program;

        ConverseRMS__c converseRMS = new ConverseRMS__c();
        converseRMS.Offset_Of_Kick_Off_To_PTLF__c = 1;
        converseRMS.Offset_Of_PTLF_To_Delivered__c = 1;
        converseRMS.Offset_Of_Insp_To_CS_Confirm__c = 1;
        converseRMS.Offset_Of_CS_Confirm_To_WSL_Confirm__c = 1;
        converseRMS.Offset_Of_WSL_Confirm_To_Inbound__c = 1;
        converseRMS.Offset_Of_Delivered_To_Insp__c = 1;
        converseRMS.Offset_Of_Inbound_To_Completed__c = 1;
        insert converseRMS;
        RTV_Summary__c summary = new RTV_Summary__c();
        summary.Status__c = 'Pending';
        summary.Expected_Date_Of_Inpected__c = Date.today();
        summary.Application_QTY__c = 100;
        summary.RTV_Program__c = program.id;
        insert summary;

        summary.Status__c = 'Ready';
        update summary;

        summary.Expected_Date_Of_Inpected__c = Date.today().addDays(1);
        summary.Actual_Date_Of_Delivered__c = Date.today().addDays(1);
        summary.Actual_Date_Of_Delivered__c = Date.today();
        summary.Insp_Submit_Time__c = Datetime.now();
        summary.Insp_CS_Approve_Time__c = Datetime.now();
        summary.Insp_Final_Reject_Time__c = Datetime.now();
        summary.Insp_Final_Approve_Time__c = Datetime.now();
        summary.LF_WH_Inbound_Date__c = Date.today();
        summary.CS_Inbound_Date__c = Date.today();
        update summary;

        summary.Insp_Submit_Time__c = Datetime.now().addDays(1);
        summary.Insp_CS_Approve_Time__c = Datetime.now().addDays(1);
        summary.Insp_Final_Reject_Time__c = Datetime.now().addDays(1);
        summary.Insp_Final_Approve_Time__c = Datetime.now().addDays(1);
        summary.LF_WH_Inbound_Date__c = Date.today().addDays(1);
        summary.CS_Inbound_Date__c = Date.today().addDays(1);
        summary.Status__c = 'POST to LF';
        update summary;

        summary.Status__c = 'Completed';
        update summary;

    }
}