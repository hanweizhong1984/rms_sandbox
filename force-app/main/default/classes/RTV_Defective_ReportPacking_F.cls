public with sharing class RTV_Defective_ReportPacking_F {
    public Id orderId = ApexPages.currentPage().getParameters().get('orderId');
    
    public List<RTV_Order_Item__c> results {get; set;}
    public String isMaterial{get; set;}
    public String unMaterial{get; set;}

    public RTV_Defective_ReportPacking_F() {

        this.isMaterial = '无实物退残';
        this.unMaterial = '';
        this.results = [
            SELECT  Material_Code__c,
                SKU_Size_US__c,
                SKU_Size_Asia__c,
                BU_2__c,
                Season_Code_CN__c,
                Application_QTY__c,
                MSRP__c,
                Defective_Box_Code__c, 
                Defective_Reason__c,
                Defective_Source__c,
                Application_Remark__c,
                IsMaterial__c
            FROM RTV_Order_Item__c
            WHERE RTV_Order__c = :orderId
            AND BU_2__c = 'FW'

        ];
    } 
}