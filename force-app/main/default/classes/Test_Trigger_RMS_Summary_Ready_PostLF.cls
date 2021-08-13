@IsTest(isParallel=true)
public class Test_Trigger_RMS_Summary_Ready_PostLF {
    @IsTest
    public static void test() {
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
        
        // masterdata.account group
        RMS_Account_Group__c acgroup = new RMS_Account_Group__c();
        insert acgroup;
        
        // masterdata.soldto
        RMS_Sold_To__c soldto = new RMS_Sold_To__c();
        soldto.Account_Group__c = acgroup.Id;
        insert soldto;
        
        // masterdata.shipto
        RMS_Ship_To__c shipto = new RMS_Ship_To__c();
        shipto.Name = '100001';
        shipto.Sold_To_Code__c = soldto.Id;
        insert shipto;
        
        // program
        RTV_Program__c program = new RTV_Program__c();
        insert program;
        
        // summarybudget
        RTV_RP_Summary_Budget__c summaryBg = new RTV_RP_Summary_Budget__c();
        summaryBg.Return_Program__c = program.Id;
        summaryBg.Account_Group__c = acgroup.Id;
        summaryBg.Tack_Back_Net__c = 100;
        summaryBg.MSRP__c = 100;
        summaryBg.QTY__c = 100;
        insert summaryBg;
        
        // summary
        RTV_Summary__c summary = new RTV_Summary__c();
        summary.RTV_Program__c = program.Id;
        summary.Account_Group__c = acgroup.Id;
        summary.Summary_Budget__c = summaryBg.Id;
        summary.Status__c = 'Pending';
        insert summary;
        
        // 创建所有AccountGroup下所有shipto白名单
        summary.Status__c = 'Ready';
        update summary;
        
        // 更新现有白名单
        summary.Status__c = 'Pending';
        update summary;
        summary.Status__c = 'Ready';
        update summary;
    }
}