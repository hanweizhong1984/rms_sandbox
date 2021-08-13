public with sharing class RTV_Order_UploadSellingPriceCtrl {

    /** 参数summary */
    public final Id theSummaryId = ApexPages.currentPage().getParameters().get('summaryId');
    
    /** 上传的csv文件正文 */
    public transient Blob fileUploadBody {get; set;}
    public String fileUploadName {get; set;}
    
    /** 文件编码 */
    public List<ApexPages.SelectOption> fileCharsetOpts {get{return RMS_CSV_Iterator.CHARSET_OPTIONS;}}
    public String fileCharset = fileCharsetOpts.get(0).getValue();
    public String getFileCharset() {return fileCharset;}
    public void setFileCharset(String value) {this.fileCharset=value;}

    /** 目标item */
    private Map<String, RTV_Order_Item__c> existItems;
    /** 待更新记录 */
    private Map<String, RTV_Order_Item__c> updateItems;

    /** 上传是否有错误 */
    private Boolean isError = false;

    /** csv的必须列 */
    private static String[] Csv_Fields = new String[]{
        'LF Order Auth Code', 'BU', 'Material Code', 'Size (US)', 'Season Code (CN)', 'Selling Type', 'Selling Unit Price (CNY/excl.VAT)'};

    public RTV_Order_UploadSellingPriceCtrl() {
        // Nothing
    }

    /** 返回上一页 */
    public PageReference cancel() {
        String url = '/lightning/o/RTV_Summary__c/list';
        if (this.theSummaryId != null) {
            url = String.format('/lightning/r/RTV_Summary__c/{0}/view', new List<string>{this.theSummaryId});
        }
        return new PageReference(url);
    }
    
    /** 上传 */
    public void upload() {
        this.existItems = new Map<String, RTV_Order_Item__c>();
        this.updateItems = new Map<String, RTV_Order_Item__c>();
        this.isError = false;

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
        System.debug('doUpload');

        // 创建csv迭代器
        RMS_CSV_Iterator csvIter = new RMS_CSV_Iterator(this.fileUploadBody, this.fileCharset);
        csvIter.skipTitleLineIgnoreCase(Csv_Fields);
        
        // 检索order前，先遍历一次csv缩小检索范围
        List<RMS_CSV_Iterator.OneLineInfo> csvTable = new List<RMS_CSV_Iterator.OneLineInfo>();
        Set<String> lfOrderCodes = new Set<String>();
        while (csvIter.next()) {
            RMS_CSV_Iterator.OneLineInfo tr = csvIter.getOneLineInfo();
            
            // 记录该行内容
            csvTable.add(tr);
            lfOrderCodes.add(tr.get('LF Order Auth Code'));
        }
        System.debug('lfOrderCodes' + lfOrderCodes.size());
        
        // 检索item
        this.queryItems(lfOrderCodes);

        // 遍历csv
        for (RMS_CSV_Iterator.OneLineInfo tr: csvTable) {
            System.debug('tr.LF Order Auth Code' + tr.get('LF Order Auth Code'));

            // 通过'LF Order Auth Code'获取'OrderCode'和'BU2'
            String lfOrderCode = tr.get('LF Order Auth Code');
            String orderCode = lfOrderCode.substring(0, lfOrderCode.length()-2);
            
            // 更新item
            changeItem(orderCode, tr);
        }
        
        // 更新Items
        if (!this.updateItems.isEmpty()) {
            upsert this.updateItems.values();
            if(!this.isError){
                RMS_CommonUtil.pageAddMessage(ApexPages.severity.CONFIRM, 'Update selling price success');
            }
        } else {
            RMS_CommonUtil.pageAddMessage(ApexPages.severity.INFO, 'No item found');
        }
    }

    /**
     * 统计item
     */
    private void queryItems(Set<String> csvLfOrderCodes) {
        
        // 检索item，统计各 LF_Order_Auth_Code__c 对应的itemlist
        for (RTV_Order_Item__c item: [
            SELECT Id, Name, LF_Order_Auth_Code__c, UniqueKey__c,
                Material_Code__c, BU_2__c, SKU_Size_US__c, Season_Code_CN__c, 
                RTV_Order__r.Order_Auth_Code__c
            FROM RTV_Order_Item__c
            WHERE LF_Order_Auth_Code__c IN :csvLfOrderCodes
        ]) {
            // 获取现存的item
            this.existItems.put(item.UniqueKey__c, item);
        }
    }

    /** 修改 RTV_Order_Item__c */
    private void changeItem(String orderCode, RMS_CSV_Iterator.OneLineInfo tr) {
        // 获取csv中的目标item
        RTV_Order_Item__c csvInfo = new RTV_Order_Item__c();
        csvInfo.Material_Code__c = tr.get('Material Code');
        csvInfo.BU_2__c = tr.get('BU');
        csvInfo.Sku_Size_US__c = tr.get('Size (US)');
        csvInfo.Season_Code_CN__c = tr.get('Season Code (CN)');
        csvInfo.UniqueKey__c = RMS_CommonUtil.item_getUniqueKey(orderCode, csvInfo);
        
        // 获取数据库中的item
        RTV_Order_Item__c item = this.existItems.get(csvInfo.UniqueKey__c);
        // 更新item
        if (item != null) {
            System.debug('存在' + item);
            // 添加到待更新（只添加需要更新的字段）
            this.updateItems.put(item.UniqueKey__c, new RTV_Order_Item__c(
                Id = item.Id,
                UniqueKey__c = item.UniqueKey__c,
                Selling_Type__c = tr.get('Selling Type'),
                Selling_Unit_Price__c = String.isBlank(tr.get('Selling Unit Price (CNY/excl.VAT)'))? 0: Decimal.valueOf(tr.get('Selling Unit Price (CNY/excl.VAT)'))
            ));
        }else {
            System.debug('找不到' + tr.values());
            this.isError = true;
            RMS_CommonUtil.pageAddMessage(ApexPages.severity.ERROR, 'No item found:' + tr.values());
        }
    }
}