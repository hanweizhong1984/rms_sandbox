public with sharing class RTV_Order_UploadDeliveryCtrl {
    /** 参数：summary.id */
    public final Id summaryId = Apexpages.currentPage().getParameters().get('summaryId');
    
    /** 上传的文件正文 */
    public transient Blob fileUploadBody {get; set;}
    public String fileUploadName {get; set;}
    
    /** 文件编码 */
    public List<ApexPages.SelectOption> fileCharsetOpts {get{return RMS_CSV_Iterator.CHARSET_OPTIONS;}}
    public String fileCharset = fileCharsetOpts.get(0).getValue();
    public String getFileCharset() {return fileCharset;}
    public void setFileCharset(String value) {this.fileCharset=value;}
    
    /** 导入结果 */
    public List<RTV_LF_Order__c> resLfOrders {get; set;}

    /** 上传是否有错误信息 */
    private Boolean isError = false;
    
    /** 返回上一页 */
    public PageReference cancel(){
        return new PageReference(
            this.summaryId != null ? '/' + this.summaryId :
            '/lightning/o/RTV_Order__c/list'
        );
    }
    
    /** 执行上传 */
    public void upload() {
        // 初期化
        this.resLfOrders = new List<RTV_LF_Order__c>();
        this.isError = false;
        
        // 验证表单
        if (fileUploadBody == null) {
            ApexPages.addMessage(new ApexPages.message(ApexPages.severity.ERROR, 'file is required'));
            return;
        }
        // 上传
        try {
            this.doUpload();
        } 
        // 捕捉dml错误 (包括自定义的validate rule)
        catch(Exception err) {
            if (err.getMessage().contains('FIELD_CUSTOM_VALIDATION_EXCEPTION')) {
                // 自定义的validate rule会自动添加message
            } else {
                ApexPages.addMessage(new ApexPages.message(ApexPages.severity.ERROR, err.getMessage()));
            }
        }
    }
    
    /** 执行上传 */
    private void doUpload() {
        // 创建csv迭代器
        RMS_CSV_Iterator csvIter = new RMS_CSV_Iterator(this.fileUploadBody, this.fileCharset);
        csvIter.skipTitleLine(new String[]{'退货授权号', '实收', '差异', '箱数', '体积', 'Date-到货', 'Date-提货'});
        
        // 先遍历一次csv，统计'退货授权号'，缩小范围
        List<RMS_CSV_Iterator.OneLineInfo> csvTable = new List<RMS_CSV_Iterator.OneLineInfo>();
        Set<String> lfOrderCodes = new Set<String>();
        while (csvIter.next()) {
            RMS_CSV_Iterator.OneLineInfo tr = csvIter.getOneLineInfo();
            
            csvTable.add(tr);
            lfOrderCodes.add(tr.get('退货授权号'));
        }
        
        // 检索csv中'退货授权号'对应的lforder
        Map<String, RTV_LF_Order__c> lfOrderMap = new Map<String, RTV_LF_Order__c>();
        List<RTV_LF_Order__c> lfOrderList;
        if (this.summaryId != null) {
            lfOrderList = [
                SELECT Id, LF_Order_Auth_Code__c, RTV_Order__c, RTV_Order__r.Name,  RTV_Order__r.Status__c
                FROM RTV_LF_Order__c
                WHERE LF_Order_Auth_Code__c IN :lfOrderCodes
                AND RTV_Order__r.Return_Summary__c = :this.summaryId
            ];
        } else {
            lfOrderList = [
                SELECT Id, LF_Order_Auth_Code__c, RTV_Order__c, RTV_Order__r.Name,  RTV_Order__r.Status__c
                FROM RTV_LF_Order__c
                WHERE LF_Order_Auth_Code__c IN :lfOrderCodes
            ];
        }
        for (RTV_LF_Order__c lfO: lfOrderList) {
            lfOrderMap.put(lfO.LF_Order_Auth_Code__c, lfO);
        }
        
        // 遍历csv，更新lforder的收货信息
        Map<Id, RTV_Order__c> updateOrders = new Map<Id, RTV_Order__c>();
        Map<Id, RTV_LF_Order__c> updateLfOrders = new Map<Id, RTV_LF_Order__c>();
        for (RMS_CSV_Iterator.OneLineInfo tr: csvTable) {
            String lfOrderCode = tr.get('退货授权号');
            RTV_LF_Order__c lfO = lfOrderMap.get(lfOrderCode);
            if (lfO == null) {
                isError = true;
                ApexPages.addMessage(new ApexPages.message(ApexPages.severity.WARNING, '退货授权号错误: ' + lfOrderCode));
                continue;
            }
            
            // 更新lforder的收货信息
            RTV_LF_Order__c updLO = new RTV_LF_Order__c();
            updLO.Id = lfO.Id;
            updLO.Delivery_QTY__c = Decimal.valueOf(tr.get('实收'));
            updLO.Delivery_Diff_QTY__c = Decimal.valueOf(tr.get('差异'));
            updLO.Box_QTY__c = Decimal.valueOf(tr.get('箱数'));
            updLO.Box_Size__c = Decimal.valueOf(tr.get('体积'));
            updLO.Arrival_Date__c = RMS_CommonUtil.str2Date(tr.get('Date-到货'));
            updLO.Delivery_Date__c = RMS_CommonUtil.str2Date(tr.get('Date-提货'));
            updateLfOrders.put(updLO.Id, updLO);
            
            // 更新order的状态
            RTV_Order__c order = new RTV_Order__c();
            order.Id = lfO.RTV_Order__c;
            order.Status__c = 'Delivered';
            updateOrders.put(order.Id, order);
            
            // （仅页面显示用）更新结果
            if (this.resLfOrders.size() < 50) {
                RTV_LF_Order__c res = new RTV_LF_Order__c();
                res.RTV_Order__c = lfO.RTV_Order__c;
                res.RTV_Order__r = new RTV_Order__c(Status__c=order.Status__c);
                res.LF_Order_Auth_Code__c = lfO.LF_Order_Auth_Code__c;
                res.Delivery_QTY__c = updLO.Delivery_QTY__c;
                res.Delivery_Diff_QTY__c = updLO.Delivery_Diff_QTY__c;
                res.Box_QTY__c = updLO.Box_QTY__c;
                res.Box_Size__c = updLO.Box_Size__c;
                res.Arrival_Date__c = updLO.Arrival_Date__c;
                res.Delivery_Date__c = updLO.Delivery_Date__c;
                this.resLfOrders.add(res);
            }
        }
        
        // 更新
        if (!updateOrders.isEmpty()) {
            update updateLfOrders.values();
            update updateOrders.values();
            if(!isError){
                ApexPages.addMessage(new ApexPages.message(ApexPages.severity.CONFIRM, '上传成功'));
            }
        } else {
            ApexPages.addMessage(new ApexPages.message(ApexPages.severity.ERROR, '上传失败'));
        }
    }
}