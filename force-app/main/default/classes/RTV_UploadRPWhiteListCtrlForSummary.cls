public with sharing class RTV_UploadRPWhiteListCtrlForSummary {
    
    /** 画面参数：sumamryId */
    String summaryId = ApexPages.currentPage().getParameters().get('summaryId');

    private RTV_Summary__c summary;
    
    /** 上传的csv */
    public transient Blob fileUploadBody{get;set;}
    public String fileUploadName{get;set;}
    
    /** 文件编码 */
    public List<ApexPages.SelectOption> fileCharsetOpts {get{return RMS_CSV_Iterator.CHARSET_OPTIONS;}}
    public String fileCharset = fileCharsetOpts.get(0).getValue();
    public String getFileCharset() {return fileCharset;}
    public void setFileCharset(String value) {this.fileCharset=value;}
    
    /** csv必须列 */
    public static final String[] CsvFields = new String[]{'Ship To'};
    
    /** 结果：有效化的shipto */
    public List<RTV_RP_Ship_To__c> shiptoWL {get; set;}
    
    public List<RTV_RP_Ship_To__c> resNewShipToWL {get; set;}
    public List<RTV_RP_Ship_To__c> resUpdShipToWL {get; set;}
    
    /** 返回上一页 */
    public PageReference cancel(){
        PageReference returnPage = new PageReference('/' + summaryId);
        returnPage.setRedirect(true);
        return returnPage;
    }
    
    /** 执行上传 */
    public void uploadFile() {
        this.resNewShipToWL = new List<RTV_RP_Ship_To__c>();
        this.resUpdShipToWL = new List<RTV_RP_Ship_To__c>();
        try {
            // 判断input
            if (fileUploadBody == null) {
                ApexPages.addMessage(new ApexPages.message(ApexPages.severity.ERROR, 'file is required'));
                return;
            }
            
            // 检索summary
            this.summary = [
                SELECT Id, Summary_Budget__c, Account_Group__c, RTV_Program__c, RTV_Program__r.OwnerId
                FROM RTV_Summary__c WHERE Id = :summaryId LIMIT 1
            ];
            
            // 统计csv中各shipToCode
            Set<String> csvShipToCodes = this.getCsvShipToCodes();
            
            // 检索csv中各shipToCode对应的，该AccountGroup下的shipto对象
            Map<String, RMS_Ship_To__c> csvShipToMap = this.queryShipTos(csvShipToCodes);
            
            // 如果csv中有不在当前Account_Group的shipToCode时
            Set<String> otherCodes = new Set<String>(csvShipToCodes);
            otherCodes.removeAll(csvShipToMap.KeySet());
            if (!otherCodes.isEmpty()) {
                ApexPages.addMessage(new ApexPages.message(ApexPages.severity.ERROR, 'Sorry, please do not upload the Ship-to of other Account Group: ' + otherCodes.toString()));
                return;
            }
            
            // 检索该summary的白名单
            Map<String, RTV_RP_Ship_To__c> shipToWhiteMap = this.queryShipToWhiteList();
            
            // 获取所有待处理的shipToCode
            Set<String> allCodes = new Set<String>();
            allCodes.addAll(csvShipToMap.KeySet());
            allCodes.addAll(shipToWhiteMap.KeySet());
            
            for (String shipToCode: allCodes) {
                RMS_Ship_To__c csvShipTo = csvShipToMap.get(shipToCode.toUpperCase());
                RTV_RP_Ship_To__c existShipToWL = shipToWhiteMap.get(shipToCode.toUpperCase());
                
                // 当shiptocode在csv中，不在白名单中，且可以新建(完全没有白名单)时
                if (csvShipTo != null && existShipToWL == null && shipToWhiteMap.isEmpty()) {
                    // 新增shipto白名单
                    RTV_RP_Ship_To__c sprp = new RTV_RP_Ship_To__c();
                    sprp.Removed__c = false;
                    
                    // 基础信息
                    sprp.RTV_Program__c = summary.RTV_Program__c;
                    sprp.Summary_Budget__c = summary.Summary_Budget__c;
                    sprp.Summary__c = summary.Id;
                    sprp.Sold_To__c = csvShipTo.Sold_To_Code__c;
                    sprp.Ship_To__c = csvShipTo.Id;
                    
                    //Owner(和order的owner逻辑一致)
                    sprp.OwnerId = csvShipTo.OwnerId;
                    
                    this.resNewShipToWL.add(sprp);
                }
                // 当shipto在csv中，在白名单中时
                else if (csvShipTo != null && existShipToWL != null) {
                    // 修改shipto白名单(unremove)
                    existShipToWL.Removed__c = false;
                    existShipToWL.OwnerId = csvShipTo.OwnerId;
                    this.resUpdShipToWL.add(existShipToWL);
                }
                // 当shipto不在csv中，在白名单中时
                else if (csvShipTo == null && existShipToWL != null) {
                    // 修改shipto白名单(remove)
                    existShipToWL.Removed__c = true;
                    existShipToWL.OwnerId = summary.RTV_Program__r.OwnerId;
                    this.resUpdShipToWL.add(existShipToWL);
                }
            }
            
            // 执行新建和更新
            if (!this.resNewShipToWL.isEmpty()) {
                insert this.resNewShipToWL;
            }
            if (!this.resUpdShipToWL.isEmpty()) {
                update this.resUpdShipToWL;
            }
            ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.CONFIRM, 'Upload Success'));
        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.message(ApexPages.severity.ERROR, e.getMessage()));
        }
        
    }
    
    /** 获取csv中的shipToCode集合 */ 
    private Set<String> getCsvShipToCodes() {
        Set<String> csvShipToCodes = new Set<String>();
        
        RMS_CSV_Iterator csvIter = new RMS_CSV_Iterator(this.fileUploadBody, this.fileCharset);
        csvIter.skipTitleLine(CsvFields);
        
        while (csvIter.next()) {
            String shipToCode = csvIter.getLineAsList()[0];
            csvShipToCodes.add(shipToCode.toUpperCase());   
        }
        return csvShipToCodes;
    }
        
    /** 检索shipToCode对应的shipto对象(当前Account_Group内) */
    private Map<String, RMS_Ship_To__c> queryShipTos(Set<String> shipToCodes) {
        Map<String, RMS_Ship_To__c> csvShipToMap = new Map<String, RMS_Ship_To__c>();
        
        for (RMS_Ship_To__c shipTo: [
            SELECT Name,
                OwnerId,
                Owner.Profile.Name, 
                Sold_To_Code__c, 
                Sold_To_Code__r.TT_FTW_EG__c,
                Sold_To_Code__r.TT_FW_Seasonal__c,
                Sold_To_Code__r.TT_APP_ACC__c,
                Sold_To_Code__r.OwnerId, 
                Sold_To_Code__r.Owner.Profile.Name, 
                Sold_To_Code__r.Account_Group__r.Name,
                Sold_To_Code__r.Account_Group__r.OwnerId,
                Sold_To_Code__r.Account_Group__r.Owner.Profile.Name
            FROM RMS_Ship_To__c 
            WHERE Sold_To_Code__r.Account_Group__c = :this.summary.Account_Group__c
            AND Name IN :shipToCodes
        ]) {
            csvShipToMap.put(shipTo.Name.toUpperCase(), shipTo);
        }
        return csvShipToMap;
    }
    
    /** 检索shipto白名单 */
    private Map<String, RTV_RP_Ship_To__c> queryShipToWhiteList() {
        Map<String, RTV_RP_Ship_To__c> shipToWhiteMap = new Map<String, RTV_RP_Ship_To__c>();
        
        for (RTV_RP_Ship_To__c sprp: [
            SELECT Id, Sold_To__c, Ship_To__r.Name, Removed__c
            FROM RTV_RP_Ship_To__c 
            WHERE Summary__c = :this.summaryId
        ]) {
            shipToWhiteMap.put(sprp.Ship_To__r.Name.toUpperCase(), sprp);
        }
        return shipToWhiteMap;
    }
}