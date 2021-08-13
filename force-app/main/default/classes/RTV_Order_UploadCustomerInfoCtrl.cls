public with sharing class RTV_Order_UploadCustomerInfoCtrl {

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

    /** 目标Order */
    private Map<String, RTV_Order__c> existOrders;
    private Map<Id, RMS_Ship_To__c> existShiptos;
    /** 待更新记录 */
    private Map<String, RTV_Order__c> updateOrders;
    private Map<Id, RMS_Ship_To__c> updateShiptos;

    /** 上传是否有错误 */
    private Boolean isError = false;

    /** csv的必须列 */
    private static String[] Csv_Fields = new String[]{
        'Order Code', 'Earliest Delivery Date', 'Ship-To Contact', 'Ship-To Phone1', 'Ship-To Phone2', 'Ship-To Address', 'AP Boxes', 'AC Boxes', 'FW Boxes'};

    public RTV_Order_UploadCustomerInfoCtrl() {
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
        this.existOrders = new Map<String, RTV_Order__c>(); 
        this.updateOrders = new Map<String, RTV_Order__c>();
        this.existShiptos = new Map<Id, RMS_Ship_To__c>();
        this.updateShiptos = new Map<Id, RMS_Ship_To__c>();
        this.isError = false;

        // 检查input
        if (this.fileUploadBody == null) {
            RMS_CommonUtil.pageAddMessage(ApexPages.severity.ERROR, '请选择上传文件！');
            return;
        }
        
        // 执行上传
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

    /** 执行上传 */
    private void doUpload() {
        // 创建csv迭代器
        RMS_CSV_Iterator csvIter = new RMS_CSV_Iterator(this.fileUploadBody, this.fileCharset);
        csvIter.skipTitleLineIgnoreCase(Csv_Fields);
        
        // 检索order前，先遍历一次csv缩小检索范围
        List<RMS_CSV_Iterator.OneLineInfo> csvTable = new List<RMS_CSV_Iterator.OneLineInfo>();
        Set<String> orderCodes = new Set<String>();
        while (csvIter.next()) {
            RMS_CSV_Iterator.OneLineInfo tr = csvIter.getOneLineInfo();
            
            // 记录该行内容
            csvTable.add(tr);
            orderCodes.add(tr.get('Order Code'));
        }
        
        // 检索order
        this.queryOrders(orderCodes);
        
        // 遍历csv
        for (RMS_CSV_Iterator.OneLineInfo tr: csvTable) {
            // 更新order
            changOrder(tr);
        }
        
        // 更新orders
        if (!this.updateOrders.isEmpty()) {
            upsert this.updateOrders.values();
            // 同步到Shipto
            if (!this.updateShiptos.isEmpty()) {
                update this.updateShiptos.values();
            }

            if(!this.isError){
                RMS_CommonUtil.pageAddMessage(ApexPages.severity.CONFIRM, '客户信息更新成功！');
            }
        } else {
            RMS_CommonUtil.pageAddMessage(ApexPages.severity.INFO, '客户信息不存在！');
        }
    }

    /**
     * 统计item
     */
    private void queryOrders(Set<String> csvorderCodes) {
        Set<Id> shiptoIds = new Set<Id>();

        // 检索Order
        for (RTV_Order__c item: [
            SELECT Id, Name, Status__c, Earliest_Delivery_Date__c, Ship_To__c, Ship_To_Contact__c, 
                Ship_To_Phone1__c, Ship_To_Phone2__c, Ship_To_Address__c, AP_Boxes__c, AC_Boxes__c, FW_Boxes__c
            FROM RTV_Order__c
            WHERE Name IN :csvorderCodes
        ]) {
            // 获取现存的order
            this.existOrders.put(item.Name, item);
            shiptoIds.add(item.Ship_To__c);
        }

        this.existShiptos = new Map<Id,RMS_Ship_To__c>([SELECT Id, Name FROM RMS_Ship_To__c WHERE Id in :shiptoIds]);
    }

    /** 修改 RTV_Order__c */
    private void changOrder(RMS_CSV_Iterator.OneLineInfo tr) {
        // 获取数据库中的order
        RTV_Order__c item = this.existOrders.get(tr.get('Order Code'));
        // 更新order
        if (item != null) {
            if(item.Status__c == 'Ready'){
                if(String.isNotBlank(tr.get('Ship-To Phone1')) || String.isNotBlank(tr.get('Ship-To Phone2'))){
                    // 添加到待更新（只添加需要更新的字段）
                    RTV_Order__c order = new RTV_Order__c();
                    order.Id = item.Id;
                    order.Name = item.Name;
                    if(String.isNotBlank(tr.get('Earliest Delivery Date'))){
                        order.Earliest_Delivery_Date__c = RMS_CommonUtil.str2Date(tr.get('Earliest Delivery Date').trim());
                    }
                    order.Ship_To_Contact__c = tr.get('Ship-To Contact').trim();
                    order.Ship_To_Phone1__c = tr.get('Ship-To Phone1').trim();
                    order.Ship_To_Phone2__c = tr.get('Ship-To Phone2').trim();
                    order.Ship_To_Address__c = tr.get('Ship-To Address').trim();
                    order.AP_Boxes__c = String.isBlank(tr.get('AP Boxes'))? null: Decimal.valueOf(tr.get('AP Boxes').trim());
                    order.AC_Boxes__c = String.isBlank(tr.get('AC Boxes'))? null: Decimal.valueOf(tr.get('AC Boxes').trim());
                    order.FW_Boxes__c = String.isBlank(tr.get('FW Boxes'))? null: Decimal.valueOf(tr.get('FW Boxes').trim());

                    this.updateOrders.put(item.Name, order);

                    if(this.existShiptos.containsKey(item.Ship_To__c)){
                        RMS_Ship_To__c shipTo = this.existShiptos.get(item.Ship_To__c);
                        shipTo.Contact_Pr__c = order.Ship_To_Contact__c;
                        shipTo.Contact_Tel1__c = order.Ship_To_Phone1__c;
                        shipTo.Contact_Tel2__c = order.Ship_To_Phone2__c;
                        shipTo.Dely_Addr__c = order.Ship_To_Address__c;
                        this.updateShiptos.put(item.Id, shipTo);
                    }
                } else {
                    this.isError = true;
                    RMS_CommonUtil.pageAddMessage(ApexPages.severity.ERROR, '两个电话必填一个:' + tr.values());
                }
            }else {
                this.isError = true;
                RMS_CommonUtil.pageAddMessage(ApexPages.severity.ERROR, '该订单状态下不能更新客户信息:' + tr.values());
            }
        }else {
            this.isError = true;
            RMS_CommonUtil.pageAddMessage(ApexPages.severity.ERROR, '找不到该订单:' + tr.values());
        }
    }
}