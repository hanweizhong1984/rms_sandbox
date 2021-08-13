@IsTest(isParallel=true)
public class Test_Trigger_RMS_Access_Summary {
    @IsTest
    static void test() {
        // setting
        if ([
            SELECT Offset_Of_Kick_Off_To_PTLF__c,
                Offset_Of_PTLF_To_Delivered__c,
                Offset_Of_Delivered_To_Insp__c,
                Offset_Of_Insp_To_CS_Confirm__c,
                Offset_Of_CS_Confirm_To_WSL_Confirm__c,
                Offset_Of_WSL_Confirm_To_Inbound__c,
                Offset_Of_Inbound_To_Completed__c 
            FROM ConverseRMS__c
        ].isEmpty()) {
            insert new ConverseRMS__c(
                Offset_Of_Kick_Off_To_PTLF__c = 1,
                Offset_Of_PTLF_To_Delivered__c = 1,
                Offset_Of_Delivered_To_Insp__c = 1,
                Offset_Of_Insp_To_CS_Confirm__c = 1,
                Offset_Of_CS_Confirm_To_WSL_Confirm__c = 1,
                Offset_Of_WSL_Confirm_To_Inbound__c = 1,
                Offset_Of_Inbound_To_Completed__c = 1
            );
        }
        
        RTV_Summary__c summary = new RTV_Summary__c();
        summary.OwnerId = UserInfo.getUserId();
        summary.Status__c = 'Pending';
        insert summary;
        
        summary.Status__c = 'Ready';
        update summary;
    }
}