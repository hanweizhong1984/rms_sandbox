@IsTest(isParallel=true)
public with sharing class Test_RTV_Order_UploadFOB {
    @isTest
    public static void test() {
        RTV_Defective__c def = new RTV_Defective__c();
        def.name = 'def';
        def.Type__c = 'FTW';
        def.Start_Date__c = Date.today();
        def.End_Date__c = Date.today().addDays(30);
        insert def;

        RTV_Order__c order = new RTV_Order__c();
        order.RTV_Defective_FW__c =def.ID;
        order.Status__c = 'Ready';
        order.Name = RMS_CommonUtil.order_getCode('xxx', '01)xx', 'xxx');
        insert order;

        RTV_Order_Item__c item = new RTV_Order_Item__c();
        item.RTV_Order__c = order.id;
        item.Material_Code__c = '111111';
        item.FOB_CNY__c = 100;
        item.FOB_USD__c = 100;
        item.name = 'item1111';
        insert item;

        RTV_Order_UploadFOB ctrl = new RTV_Order_UploadFOB();
        ctrl.upload();
        ctrl.fileUploadBody = Blob.valueof(
            '\r' +
            'Defective Name,Finance Code,Start Date,End Date,Order Code,Status,Item Code,FOB(CNY),FOB(USD)\r' + 
            def.name + ',1100,'+def.Start_Date__c+','+def.End_Date__c+','+order.Name+','+Order.Status__c+','+
            item.name+',200,200'+'\r'
        );
        ctrl.fileUploadName = 'xxxx';
        ctrl.getFileCharset();
        ctrl.setFileCharset('UTF-8');
        ctrl.upload();
        ctrl.cancel();
        
        ApexPages.currentPage().getParameters().put('id', def.Id);
        RTV_Order_UploadFOB ctrl2 = new RTV_Order_UploadFOB();
        ctrl2.cancel();

    }
}