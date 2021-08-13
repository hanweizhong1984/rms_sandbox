public with sharing class RTV_Order_ReportPackingListCtrl {
    
    public Id summaryId = ApexPages.currentPage().getParameters().get('summaryId');
    
    public List<RTV_Order_Packing__c> results {get; set;}
    
    public RTV_Order_ReportPackingListCtrl() {
        this.results = [
            SELECT Box_Code__c,
                Application_QTY__c,
                RTV_Order_Item__r.Material_Code__c,
                RTV_Order_Item__r.BU_2__c,
                RTV_Order_Item__r.SKU_Size_US__c, 
                RTV_Order_Item__r.SKU_Size_Asia__c, 
                RTV_Order_Item__r.Season_Code_CN__c,
                RTV_Order_Item__r.RTV_Order__r.Name,
                RTV_Order_Item__r.RTV_Order__r.Sold_To__r.Name,
                RTV_Order_Item__r.RTV_Order__r.Ship_To__r.Name,
                RTV_Order_Item__r.RTV_Order__r.Earliest_Delivery_Date__c
            FROM RTV_Order_Packing__c 
            WHERE RTV_Order_Item__r.RTV_Order__r.Return_Summary__c = :summaryId
        ];
    }
}