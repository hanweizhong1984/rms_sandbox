@IsTest(isParallel=true)
public class Test_Trigger_RMS_OrderItem_TotalBudget {
    @IsTest
    public static void test() {
        // program
        RTV_Program__c program = new RTV_Program__c();
        program.Name='wsltb';
        insert program;

        //accountgroup
        RMS_Account_Group__c account = new RMS_Account_Group__c();
        account.Name='01)YY';
        insert account;
        
        // skuBudget
        RTV_RP_Sku_Budget__c skuBudget = new RTV_RP_Sku_Budget__c();
        skuBudget.Return_Program__c = program.Id;
        skuBudget.Account_Group__c=account.Id;
        skuBudget.SKU_Material_Code__c = 'PDT0000001';
        skuBudget.Budget_QTY__c = 100;
        skuBudget.Budget_MSRP__c = 10000;
        skuBudget.Budget_NET__c = 10000;
        insert skuBudget;
        
        
        
        // summary
        RTV_Summary__c summary = new RTV_Summary__c();
        summary.RTV_Program__c = program.Id;
        summary.Account_Group__c = account.Id;
        summary.Status__c = 'Ready';
        insert summary;
        
        // order
        RTV_Order__c order = new RTV_Order__c();
        order.Return_Summary__c = summary.Id;
        order.Name = 'xxxx';
        order.Ship_To_Phone1__c = '13012341234';
        order.Ship_To_Phone2__c = '13012341234';
        insert order;
        
        // item
        RTV_Order_Item__c item = new RTV_Order_Item__c();
        item.RTV_Order__c = order.Id;
        item.Sku_Budget__c = skuBudget.Id;
        item.Material_Code__c = 'PDT000001';
        item.BU_2__c = 'FW';
        item.Season_Code_CN__c = '20Q1';
        item.SKU_Size_US__c = 'XL';
        item.Application_QTY__c = 99;
        item.Application_Amount__c =1000;
        item.BudgetQTY__c=0;
        item.MSRP__c = 10;
        insert item;
        
        try {
            item.Application_QTY__c = 1000;
            item.Application_Amount__c =10000;
            item.BudgetQTY__c =1;
            update item;
        } catch(Exception err) {}
    }
}