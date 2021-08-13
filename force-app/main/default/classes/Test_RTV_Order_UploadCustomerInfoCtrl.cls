@IsTest(isParallel=true)
public class Test_RTV_Order_UploadCustomerInfoCtrl {
    @isTest
    public static void test() {
        RTV_Summary__c summary = new RTV_Summary__c();
        insert summary;
        
        RTV_Order__c order = new RTV_Order__c();
        order.Return_Summary__c = summary.Id;
        order.Status__c = 'Ready';
        order.Name = 'xxxxxx';
        insert order;
        
        Date earDate = System.today().addDays(10);
        String earDateStr = earDate.year()+'/'+earDate.month()+'/'+earDate.day();
        
        ApexPages.currentPage().getParameters().put('summaryId', summary.Id);
        RTV_Order_UploadCustomerInfoCtrl ctrl = new RTV_Order_UploadCustomerInfoCtrl();
        ctrl.cancel();
        ctrl.upload();
        
        ctrl.fileUploadBody = Blob.valueof('\r' +
            'Order Code,Earliest Delivery Date,Ship-To Contact,Ship-To Phone1,Ship-To Phone2,Ship-To Address,AP Boxes,AC Boxes,FW Boxes\r' +
            order.Name + ','+earDateStr+',contact,13855556333,13055556333,address,1,1,1'
        );
        ctrl.fileUploadName = 'xxxx';
        ctrl.getFileCharset();
        ctrl.setFileCharset('UTF-8');
        ctrl.upload();
    }
}