public with sharing class RTV_Order_ReportCustomerInfoCtrl {
    public Id summaryId = ApexPages.currentPage().getParameters().get('summaryId');

    public List<RTV_Order__c> results {get; set;}
    public RTV_Summary__c summary {get; set;}
    
    public RTV_Order_ReportCustomerInfoCtrl() {
        this.summary = [
            SELECT Name, Sales_Channel__c
            FROM RTV_Summary__c
            WHERE Id = :this.summaryId
        ];
        this.results = [
            SELECT Name,
                Return_Summary__r.Sales_Channel__c,
                Sold_To__r.Name,
                Ship_To__r.Name,
                Ship_To__r.DTC_Code__c,
                Earliest_Delivery_Date__c,
                Ship_To_Contact__c, 
                Ship_To_Phone1__c, 
                Ship_To_Phone2__c, 
                Ship_To_Address__c, 
                AP_Boxes__c, 
                AC_Boxes__c, 
                FW_Boxes__c
            FROM RTV_Order__c 
            WHERE Return_Summary__c = :summaryId AND Status__c = 'Ready'
        ];
    }
}