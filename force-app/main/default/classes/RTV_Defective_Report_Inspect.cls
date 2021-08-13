public with sharing class RTV_Defective_Report_Inspect {
    String orderId = ApexPages.currentPage().getParameters().get('orderId');

    //显示结果
    public List<RTV_Order_Item_DEF_Detail__c> results {get; set;}

    public static String empty {get{return '';}}

    public RTV_Defective_Report_Inspect() {
        results = [
            SELECT BU_2__c, 
                Customer_Abbreviation__c, 
                RTV_Order_Item__r.RTV_Order__r.Sold_To__r.Name,
                RTV_Order_Item__r.RTV_Order__r.Ship_To__r.Name, 
                Customer_Name__c,
                RTV_Order_Item__r.RTV_Order__r.Name,
                RTV_Order_Item__r.LF_Order_Auth_Code__c,
                Detail_Number__c,
                RTV_Order_Item__r.Material_Code__c,
                RTV_Order_Item__r.SKU_Style__c,
                RTV_Order_Item__r.SKU_Color__c,
                RTV_Order_Item__r.SKU_Size_US__c,
                RTV_Order_Item__r.SKU_Size_Asia__c,
                RTV_Order_Item__r.Season_Code_CN__c,
                Application_QTY__c,
                Defective_Reason__c,
                Defective_Source__c,
                Defective_Reason_LF__c,
                Defective_Source_LF__c,
                Factory_Code__c,
                Actual_QTY__c,
                Acceptable_Return_QTY__c,
                Specialcase_DEF_CC__c,
                DEF_12M_18M__c,
                Reject_QTY__c,
                Reject_Reason__c,
                RTV_Order_Item__r.Defective_Box_Code__c,
                Code__c,
                RTV_Order_Item__r.Application_Remark__c,
                Actual_Diff_QTY__c,
                RTV_Order_Item__r.Selling_Unit_Price__c,
                RTV_Order_Item__r.Selling_Unit_Price_CNY_inV__c
            FROM  RTV_Order_Item_DEF_Detail__c
            WHERE RTV_Order_Item__r.RTV_Order__c = :orderId
            AND RTV_Order_Item__r.IsMaterial__c = false
            ORDER BY Detail_Number__c
        ];
    }
}