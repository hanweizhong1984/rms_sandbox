public class RTV_Order_ReportDeliveryAuth {
    
    /** url参数: summaryId */
    public String summaryId = ApexPages.currentPage().getParameters().get('summaryId');
    
    /** url参数: orderId */
    public String orderId = ApexPages.currentPage().getParameters().get('orderId');
    
    public static String empty {get{return '';}}
    
    /** 导出结果 */
    public List<RTV_LF_Order__c> results {get; set;}
    
    /** 系统日期 */
    public String SysDateStr { get{
        return System.Date.today().format();
    }}
    
    /** 构造方法 */
    public RTV_Order_ReportDeliveryAuth() {
        // 下载整个sumamry的内容
        if (this.summaryId != null) {
            this.results = [
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
                FROM RTV_LF_Order__c
                WHERE RTV_Order__r.Return_Summary__c = :this.summaryId
                AND RTV_Order__r.Status__c = 'POST to LF'
            ];
        }
        // 下载单个order的内容
        else if (this.orderId != null) {
            this.results = [
                SELECT BU_2__c, Application_Box_QTY__c,
                    Application_QTY__c, 
                    LF_Order_Auth_Code__c,
                    RTV_Order__r.Order_Auth_Code__c, 
                    RTV_Order__r.Earliest_Delivery_Date__c, 
                    RTV_Order__r.Ship_To__r.Sold_To_Code__r.Sold_To_Name_CN__c, 
                    RTV_Order__r.Ship_To__r.Province__c, 
                    RTV_Order__r.Ship_To__r.City__c, 
                    RTV_Order__r.Ship_To_Address__c, 
                    RTV_Order__r.Ship_To_Contact__c, 
                    RTV_Order__r.Ship_To_Phone1__c, 
                    RTV_Order__r.Ship_To_Phone2__c, 
                    RTV_Order__r.Ship_To__r.Sold_To_Code__r.Name, 
                    RTV_Order__r.Ship_To__r.Name
                FROM RTV_LF_Order__c
                WHERE RTV_Order__c = :this.orderId
                AND RTV_Order__r.Status__c = 'POST to LF'
            ];
        }
    }
}