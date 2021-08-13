public with sharing class RTV_Order_UploadFOB {
    /** 参数summary */
    public final Id defId = ApexPages.currentPage().getParameters().get('Id');
    
    /** 上传的csv文件正文 */
    public transient Blob fileUploadBody {get; set;}
    public String fileUploadName {get; set;}
    
    /** 文件编码 */
    public List<ApexPages.SelectOption> fileCharsetOpts {get{return RMS_CSV_Iterator.CHARSET_OPTIONS;}}
    public String fileCharset = fileCharsetOpts.get(0).getValue();
    public String getFileCharset() {return fileCharset;}
    public void setFileCharset(String value) {this.fileCharset=value;}

    /** csv的必须列 */
    private static String[] Csv_Fields = new String[]{
        'Defective Name', 'Finance Code', 'Start Date', 'End Date', 'Order Code', 'Status', 'Item Code', 'FOB(CNY)', 'FOB(USD)'};

    // 已经存在OrderItem列表
    private Map<String,RTV_Order_Item__c> orderItemMap;
    // 更新OrderItem列表
    private List<RTV_Order_Item__c> updateOrderItem;

    /** 上传 */
    public void upload()
    {
        this.orderItemMap = new Map<String,RTV_Order_Item__c>();
        this.updateOrderItem = new List<RTV_Order_Item__c>();

        // 检查input
        if (this.fileUploadBody == null) {
            RMS_CommonUtil.pageAddMessage(ApexPages.severity.ERROR, '请选择上传文件！');
            return;
        }

        Savepoint savePot = Database.setSavepoint();
        try {
            this.doUpload();
        } 
        // 捕捉dml错误 (包括自定义的validate rule)
        catch(Exception err) {
            RMS_CommonUtil.pageAddMessage(ApexPages.severity.ERROR, err.getMessage());
            Database.rollback(savePot);
        }
    }

    /** 执行上传方法 */
    public void doUpload()
    {
        // 创建csv迭代器
        RMS_CSV_Iterator csvIter = new RMS_CSV_Iterator(this.fileUploadBody, this.fileCharset);
        csvIter.skipTitleLineIgnoreCase(Csv_Fields);
        
        // 检索order前，先遍历一次csv缩小检索范围
        List<RMS_CSV_Iterator.OneLineInfo> csvTable = new List<RMS_CSV_Iterator.OneLineInfo>();
        Set<String> itemCode = new Set<String>();
        while (csvIter.next()) {
            RMS_CSV_Iterator.OneLineInfo tr = csvIter.getOneLineInfo();
            
            // 记录该行内容
            csvTable.add(tr);
            itemCode.add(tr.get('Item Code'));
        }

        this.queryOrderItem(itemCode);

        // 遍历csv
        for (RMS_CSV_Iterator.OneLineInfo tr: csvTable) {
            // 更新order Item
            updateOrderItem(tr);
        }

        if(this.updateOrderItem.size()>0)
        {
            update updateOrderItem;

            RMS_CommonUtil.pageAddMessage(ApexPages.severity.CONFIRM, '更新成功！');
        }
        else {
            RMS_CommonUtil.pageAddMessage(ApexPages.severity.CONFIRM, '无相关信息！');
        }
    }

    /** 检索Order Item */
    public void queryOrderItem(Set<String> itemCode)
    {
        for(RTV_Order_Item__c item:[SELECT ID,Name,FOB_CNY__c,FOB_USD__c ,RTV_Order__R.Name
                                    FROM RTV_Order_Item__c 
                                    WHERE RTV_Order__R.RTV_Defective__c =:this.defId 
                                    OR RTV_Order__R.RTV_Defective_FW__c =:this.defId])
        {
            this.orderItemMap.put(item.RTV_Order__R.Name+item.name,item);
        }
    }

    /** 更新OrderItem */
    public void updateOrderItem(RMS_CSV_Iterator.OneLineInfo tr)
    {
        RTV_Order_Item__c item = this.orderItemMap.get(tr.get('Order Code')+tr.get('Item Code'));
        if(item != null)
        {
            item.FOB_CNY__c = Integer.valueOf(tr.get('FOB(CNY)'));
            item.FOB_USD__c = Integer.valueOf(tr.get('FOB(USD)'));
            updateOrderItem.add(item);
        }
    }

    /** 返回上一页 */
    public PageReference cancel() {
        PageReference returnPage = new PageReference('/' + this.defId);
        returnPage.setRedirect(true);
        return returnPage;
    }
}