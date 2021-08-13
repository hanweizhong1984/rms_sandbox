public with sharing class RTV_Defective_UploadSellingPrice {

    /** 参数summary */
    public final Id defSummaryId = ApexPages.currentPage().getParameters().get('defSummaryId');
    
    /** 上传的csv文件正文 */
    public transient Blob fileUploadBody {get; set;}
    public String fileUploadName {get; set;}
    
    /** 文件编码 */
    public List<ApexPages.SelectOption> fileCharsetOpts {get{return RMS_CSV_Iterator.CHARSET_OPTIONS;}}
    public String fileCharset = fileCharsetOpts.get(0).getValue();
    public String getFileCharset() {return fileCharset;}
    public void setFileCharset(String value) {this.fileCharset=value;}

    /** 待更新记录 */
    private Map<String, RTV_Order_Item__c> updateItems;

    /** csv的必须列 */
    private static String[] Csv_Fields = new String[]{
        'LF Order Auth Code', 'DEF Order Item ID', 'Selling Type', 'Selling Unit Price (CNY/excl.VAT)'};

    /** 返回上一页 */
    public PageReference cancel() {
        PageReference returnPage = new PageReference('/' + this.defSummaryId);
        returnPage.setRedirect(true);
        return returnPage;  
    }
    
    /** 上传 */
    public void upload() {
        this.updateItems = new Map<String, RTV_Order_Item__c>();

        // 检查input
        if (this.fileUploadBody == null) {
            RMS_CommonUtil.pageAddMessage(ApexPages.severity.ERROR, 'file is required');
            return;
        }
        
        // 执行上传
        Savepoint savePot = Database.setSavepoint();
        try {
            this.doUpload();
        } 
        // 捕捉dml错误 (包括自定义的validate rule)
        catch(Exception err) {
            if (err.getMessage().contains('FIELD_CUSTOM_VALIDATION_EXCEPTION')) {
                // 自定义的validate rule会自动添加message
            } else {
                RMS_CommonUtil.pageAddMessage(ApexPages.severity.ERROR, err.getMessage());
            }
            Database.rollback(savePot);
        }
    }

    /** 执行上传 */
    private void doUpload() {
        // 创建csv迭代器
        RMS_CSV_Iterator csvIter = new RMS_CSV_Iterator(this.fileUploadBody, this.fileCharset);
        csvIter.skipTitleLineIgnoreCase(Csv_Fields);
        
        // 遍历csv
        while (csvIter.next()) {
            RMS_CSV_Iterator.OneLineInfo tr = csvIter.getOneLineInfo();
            
            // 添加到待更新（只添加需要更新的字段）
            RTV_Order_Item__c item = new RTV_Order_Item__c();
            item.Id = tr.get('DEF Order Item ID');
            item.Selling_Type__c = tr.get('Selling Type');
            item.Selling_Unit_Price__c = tr.getDecimal('Selling Unit Price (CNY/excl.VAT)', 0);
            this.updateItems.put(item.Id, item);
        }
        // 更新Items
        if (!this.updateItems.isEmpty()) {
            upsert this.updateItems.values();
            RMS_CommonUtil.pageAddMessage(ApexPages.severity.CONFIRM, 'Update selling price success');
        } else {
            RMS_CommonUtil.pageAddMessage(ApexPages.severity.INFO, 'No item found');
        }
    }
}