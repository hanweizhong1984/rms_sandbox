@IsTest(isParallel=true)
public class Test_Trigger_RMS_Order_SaveCustomerInfo {
    @IsTest
    public static void Test() {
        RMS_Ship_To__c shipto = new RMS_Ship_To__c();
        shipto.name = 'xxx';
        insert shipto;
        
        RTV_Order__c order =new RTV_Order__c();
        order.Name = 'order';
        order.Status__c = 'Ready';
        order.Ship_To__c = shipto.Id;
        order.Earliest_Delivery_Date__c = System.today();
        order.Ship_To_Phone1__c = '13012341234';
        order.Ship_To_Phone2__c = '13012341234';
        order.Ship_To_Address__c = 'xx';
        order.Ship_To_Outbound_Emails__c = 'xx@xx.xx';
        order.Application_QTY__c = 123.45;
        order.OrderPTLF__c = false;
        insert order;

        order.Ship_To_Contact__c='aaa';
        try{
            update order;
        }catch(Exception ex){
            
        }
    }
}