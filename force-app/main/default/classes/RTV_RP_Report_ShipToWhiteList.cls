public with sharing class RTV_RP_Report_ShipToWhiteList {
    
    public final Id summaryId = ApexPages.currentPage().getParameters().get('summaryId');
    
    public final Id programId = ApexPages.currentPage().getParameters().get('programId');

    public final String isReady = ApexPages.currentPage().getParameters().get('isReady');

    public List<RTV_RP_Ship_To__c> results {get; set;}

    public Boolean isRender {get; set;}
    
    public RTV_RP_Report_ShipToWhiteList() {
        if(isReady == 'true')
        {
            this.isRender = true;
        }
        else {
            this.isRender = false;
        }
        if (summaryId != null) {
            results = [
                SELECT Ship_To__r.Name,Sold_To__r.Name,Order_Auth_Code__c FROM RTV_RP_Ship_To__c WHERE Summary__c = :summaryId AND Removed__c = False
            ];
        } else if (programId != null) {
            results = [
                SELECT Ship_To__r.Name FROM RTV_RP_Ship_To__c WHERE RTV_Program__c = :programId AND Removed__c = False
            ];
        }
    }
    
}