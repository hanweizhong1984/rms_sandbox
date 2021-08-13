@IsTest(isParallel=true)
public class Test_Trigger_RMS_Order_StatusChange {
    @isTest
    public static void test() {
        RTV_Order__c order = new RTV_Order__c();
        insert order;
        
        // insert new ConverseRMS__c(
        //     Offset_Of_Kick_Off_To_PTLF__c = 1,
        //     Offset_Of_PTLF_To_Delivered__c = 1,
        //     Offset_Of_Delivered_To_Insp__c = 1,
        //     Offset_Of_Insp_To_CS_Confirm__c = 1,
        //     Offset_Of_CS_Confirm_To_WSL_Confirm__c = 1,
        //     Offset_Of_WSL_Confirm_To_Inbound__c = 1,
        //     Offset_Of_Inbound_To_Completed__c = 1
        // );
        
        // RTV_Program__c program = new RTV_Program__c();
        // insert program;
        
        // RTV_Summary__c summary = new RTV_Summary__c();
        // summary.RTV_Program__c = program.Id;
        // insert summary;
        
        // // wsl takeback
        // RTV_Order__c order = new RTV_Order__c();
        // order.Return_Summary__c = summary.Id;
        // order.Name = 'xxxxx';
        // order.Status__c = 'Pending';
        // order.Earliest_Delivery_Date__c = System.today();
        // order.Ship_To_Contact__c = 'xx';
        // order.Ship_To_Phone1__c = '13012341234';
        // order.Ship_To_Phone2__c = '13012341234';
        // order.Ship_To_Address__c = 'xx';
        // order.Ship_To_Outbound_Emails__c = 'xx@xx.xx';
        // order.Application_QTY__c = 123.45;
        // insert order;
        
        // order.Status__c='Ready';
        // update order;
        
        // order.Status__c='POST to LF';
        // update order;
        
        // order.Status__c='Delivered';
        // update order;
        
        // order.Status__c='Inspected';
        // update order;
        
        // order.Status__c='Insp Wait Approval';
        // update order;
        
        // order.Status__c='Insp Confirmed';
        // update order;
        
        // order.Status__c='Inbound';
        // update order;
        
        // order.Status__c='Completed';
        // update order;
        
        // // -------------------------------------
        // // wsl defective
        // // ------------------------------------
        // order = new RTV_Order__c();
        // order.Order_Type__c = 'RTV Defective';
        // order.Earliest_Delivery_Date__c = System.today();
        // order.Ship_To_Contact__c = 'xx';
        // order.Ship_To_Phone1__c = '13012341234';
        // order.Ship_To_Phone2__c = '13012341234';
        // order.Ship_To_Address__c = 'xx';
        // order.Ship_To_Outbound_Emails__c = 'xx@xx.xx';
        // order.Status__c = 'Pending';
        // order.Application_QTY__c = 123.45;
        // insert order;
        
        // order.Status__c='Ready';
        // update order;
        
        // order.Status__c='POST to LF';
        // update order;
        
        // order.Status__c='Delivered';
        // update order;
        
        // order.Status__c='Inspected';
        // update order;
        
        // order.Status__c='Insp Wait Approval';
        // update order;
        
        // order.Insp_Cs_Approve_Time__c = System.now();
        // update order;
        
        // order.Status__c='Inbound';
        // update order;
        
        // order.Status__c='Completed';
        // update order;
        
        // // ------------------------------------
        // // dtc takeback
        // // ------------------------------------
        // RMS_Account_Group__c acgCC = new RMS_Account_Group__c();
        // acgCC.Name = '00)CC';
        // insert acgCC;
        
        // program = new RTV_Program__c();
        // program.RecordTypeId = RMS_CommonUtil.getRecordTypes('RTV_Program__c').get('CFS DTC Takeback Kick Off').Id;
        // insert program;
        
        // summary = new RTV_Summary__c();
        // summary.RTV_Program__c = program.Id;
        // insert summary;
        
        // order = new RTV_Order__c();
        // order.Order_Type__c = 'CFS DTC Takeback';
        // order.Earliest_Delivery_Date__c = System.today();
        // order.Ship_To_Contact__c = 'xx';
        // order.Ship_To_Phone1__c = '13012341234';
        // order.Ship_To_Phone2__c = '13012341234';
        // order.Ship_To_Address__c = 'xx';
        // order.Ship_To_Outbound_Emails__c = 'xx@xx.xx';
        // order.Status__c = 'Pending';
        // order.Application_QTY__c = 123.45;
        // insert order;
        
        // order.Status__c='Ready';
        // update order;
        
        // order.Status__c='POST to LF';
        // update order;
        
        // order.Status__c='Delivered';
        // update order;
        
        // order.Status__c='Inspected';
        // update order;
        
        // order.Status__c='Insp Wait Approval';
        // update order;
        
        // order.Status__c='Insp Confirmed';
        // update order;
        
        // order.Status__c='Inbound';
        // update order;
        
        // order.Status__c='Completed';
        // update order;
            
        // // error
        // try{
        //     order.Status__c='error???';
        //     update order;
        // } catch(Exception err){
        // }
        
        // //-------------------------------------
        // // baozun
        // //-------------------------------------
        // RTV_BaoZun_Seeding__c seeding = new RTV_BaoZun_Seeding__c();
        // seeding.Year__c = 2021;
        // seeding.Month__c = 1;
        // insert seeding;
        
        // order = new RTV_Order__c();
        // order.RTV_BaoZun_Seeding__c = seeding.Id;
        // order.Name = 'xxxxx';
        // order.Status__c = 'Pending';
        // order.Seeding_Status__c = 'POST to LF';
        // insert order;
        
        // order.Seeding_Status__c = 'Inbound';
        // update order;
    }
}