public with sharing class RTV_Defective_ReportDeliveryAuth {

    private final Id defSummaryId = ApexPages.currentPage().getParameters().get('defSummaryId');

    //显示结果
    public List<RTV_LF_Order__c> results {get; set;}

    public static String empty {get{return '';}}
    public String SysDateStr { get{
        return System.Date.today().format();
    }}

    public RTV_Defective_ReportDeliveryAuth() {
        results = [
            SELECT BU_2__c, Application_Box_QTY__c, 
                Application_QTY__c, 
                LF_Order_Auth_Code__c,
                RTV_Order__r.Order_Auth_Code__c, 
                RTV_Order__r.Earliest_Delivery_Date__c, 
                RTV_Order__r.Ship_To__r.Sold_To_Code__r.Sold_To_Name_CN__c, 
                RTV_Order__r.Ship_To__r.Province__c, 
                RTV_Order__r.Ship_To__r.City__c, 
                RTV_Order__r.Ship_To_Contact__c, 
                RTV_Order__r.Ship_To_Phone1__c, 
                RTV_Order__r.Ship_To_Phone2__c, 
                RTV_Order__r.Ship_To_Address__c, 
                RTV_Order__r.Ship_To__r.Sold_To_Code__r.Name, 
                RTV_Order__r.Ship_To__r.Name
            FROM  RTV_LF_Order__c
            WHERE RTV_Order__r.RTV_DEF_Summary__c = :defSummaryId
            AND RTV_Order__r.Status__c = 'POST to LF'
        ];
    }
}