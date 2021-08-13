@IsTest(isParallel=true)
public class Test_Trigger_RMS_RP_Off_Policy {
    @IsTest
    public static void test() {
        
        RMS_Account_Group__c acgroup = new RMS_Account_Group__c();
        acgroup.Name = '00)CC';
        insert acgroup;
        
        acgroup = new RMS_Account_Group__c();
        acgroup.Name = '98)CFS';
        insert acgroup;
        
        RTV_Program__c program = newProgram('WSL Full Takeback');
        program.Program_Status__c = 'Remove';
        update program;
        program.Program_Status__c = 'Pending';
        update program;
        program.Program_Status__c = 'Off Policy';
        update program;
        
        RTV_Program__c programDis = newProgram('WSL Discount Takeback');
        programDis.Program_Status__c = 'Pending';
        update programDis;
        try {
            programDis.Program_Status__c = 'Close';
            update programDis;
        } catch(Exception err) {
        }
        programDis.Program_Status__c = 'Off Policy';
        update programDis;
    }
    
    private static RTV_Program__c newProgram(String recordType) {
        Map<String, RecordType> allTypes = RMS_CommonUtil.getRecordTypes('RTV_Program__c');
        
        RMS_Account_Group__c acgroup = new RMS_Account_Group__c();
        insert acgroup;
        
        RMS_Sold_To__c soldto = new RMS_Sold_To__c();
        soldto.Account_Group__c = acgroup.Id;
        insert soldto;
        
        RMS_Ship_To__c shipto = new RMS_Ship_To__c();
        shipto.Name = '100001';
        shipto.Sold_To_Code__c = soldto.Id;
        insert shipto;
        
        // 创建program
        RTV_Program__c program = new RTV_Program__c();
        program.RecordTypeId = allTypes.get(recordType).Id;
        program.Finance_Code__c = 'xxx';
        program.Program_Status__c = 'Pending';
        insert program;
        
        // 创建program.Summary_Budget
        RTV_RP_Summary_Budget__c summaryBg = new RTV_RP_Summary_Budget__c();
        summaryBg.Return_Program__c = program.Id;
        summaryBg.Account_Group__c = acgroup.Id;
        summaryBg.Tack_Back_Net__c = 100;
        summaryBg.MSRP__c = 100;
        summaryBg.QTY__c = 100;
        insert summaryBg;
        
        RTV_RP_Ship_To__c shiptoWL = new RTV_RP_Ship_To__c();
        shiptoWL.Sold_To__c = soldto.Id;
        shiptoWL.Ship_To__c = shipto.Id;
        shiptoWL.RTV_Program__c = program.Id;
        shiptoWL.Summary_Budget__c = summaryBg.Id;  
        insert shiptoWL;
        
        RTV_RP_Sku_Budget__c skuWL = new RTV_RP_Sku_Budget__c();
        skuWL.Return_Program__c = program.Id;
        skuWL.Sku_Material_Code__c = 'xxxx';
        insert skuWL;
        
        return program;
    }
}