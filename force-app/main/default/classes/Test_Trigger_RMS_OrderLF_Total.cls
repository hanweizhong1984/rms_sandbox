@IsTest(isParallel=true)
public class Test_Trigger_RMS_OrderLF_Total {
    @IsTest
    public static void test() {
        try{
            RTV_Order__c order = new RTV_Order__c();
            insert order;
            
            RTV_LF_Order__c lfOrder = new RTV_LF_Order__c();
            lfOrder.RTV_Order__c = order.id;
            lfOrder.Delivery_QTY__c = 123;
            insert lfOrder;
            
            lfOrder.Delivery_QTY__c = 456;
            update lfOrder;
            
            delete lfOrder;
        }catch(Exception err){
        }
    }
}