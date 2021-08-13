public with sharing class RTV_Order_UploadInspectCtrl {
    
    /** 参数summary */
    public final Id theSummaryId = ApexPages.currentPage().getParameters().get('summaryId');
    
    /** 参数order */
    public final Id theOrderId = ApexPages.currentPage().getParameters().get('orderId');
    public final RTV_Order__c theOrder;
    
    /** 上传的csv文件正文 */
    public transient Blob fileUploadBody {get; set;}
    public String fileUploadName {get; set;}
    
    /** 文件编码 */
    public List<ApexPages.SelectOption> fileCharsetOpts {get{return RMS_CSV_Iterator.CHARSET_OPTIONS;}}
    public String fileCharset = fileCharsetOpts.get(0).getValue();
    public String getFileCharset() {return fileCharset;}
    public void setFileCharset(String value) {this.fileCharset=value;}
    
    /** 运行创建item */
    public Boolean createItemIfNotFound {get; set;}

    /** 现存的order和item */
    private transient Map<String, RTV_Order__c> existOrders;
    private transient Map<String, RTV_Order_Item__c> existItems;
    private transient Map<String, RTV_Order_Inspection__c> existInspects;
    
    /** 基础表：product */
    private transient Map<String, RMS_Product__c> products;
    
    /** 基础表：tradingTerm */
    private transient Map<String, RMS_TradingTerm__c> tradingTerms;
    
    /** 待更新记录 */
    private transient Map<String, RTV_Order__c> updateOrders;
    private transient Map<String, RTV_Order_Item__c> upsertItems;
    private transient Map<String, RTV_Order_Inspection__c> upsertInspects;
    
    /** csv的必须列 (外加可选列:'季节码')*/
    private String[] Csv_Fields = new String[]{
        '退货授权号', 'Material code', 'Style', 'Color', 'Size', '申请数量', '实收', 'A', 'B', 'C', 'D', 'Reason code', '差异', '季节码'};

    /** 构造方法 */
    public RTV_Order_UploadInspectCtrl() {
        // url参数中指定了单个order时
        if (this.theOrderId != null) {
            this.theOrder = [
                SELECT Name, Order_Type__c 
                FROM RTV_Order__c 
                WHERE Id =: this.theOrderId LIMIT 1
            ];
            if(this.theOrder.Order_Type__c == 'CFS DTC Takeback' || this.theOrder.Order_Type__c == 'Digital DTC Takeback'){
                Csv_Fields  = new String[]{
                    '退货授权号', 'Bar code', 'Material code', 'Style', 'Color', 'Size', '申请数量', 'A', 'B', 'C', 'D', 'Reason code', '差异'};
            }
        }
        
        this.createItemIfNotFound = true;
    }
    
    /** 返回上一页 */
    public PageReference cancel() {
        String url = '/lightning/o/RTV_Order__c/list';
        if (this.theSummaryId != null) {
            url = '/' + this.theSummaryId;
        }
        if (this.theOrderId != null) {
            url = '/' + this.theOrderId;
        }
        return new PageReference(url);
    }
    
    /** 上传 */
    public void upload() {
        this.products = new Map<String, RMS_Product__c>();
        this.tradingTerms = new Map<String, RMS_TradingTerm__c>();
        
        this.existOrders = new Map<String, RTV_Order__c>();
        this.existItems = new Map<String, RTV_Order_Item__c>();
        this.existInspects = new Map<String, RTV_Order_Inspection__c>();
        
        this.updateOrders = new Map<String, RTV_Order__c>();
        this.upsertItems = new Map<String, RTV_Order_Item__c>();
        this.upsertInspects = new Map<String, RTV_Order_Inspection__c>();
        
        // 检查input
        if (this.fileUploadBody == null) {
            ApexPages.addMessage(new ApexPages.message(ApexPages.severity.ERROR, '请先选择上传文件！'));
            return;
        }
        // 检查summary
        if (this.theSummaryId != null) {
            List<RTV_Order__c> unDeliverdOrders = [
                SELECT Id FROM RTV_Order__c 
                WHERE Return_Summary__c = :this.theSummaryId 
                AND Status__c = 'POST to LF' LIMIT 1
            ];
            if (unDeliverdOrders.Size() > 0) {
                RMS_CommonUtil.pageAddMessage(ApexPages.severity.ERROR, '请在所有订单都完成提货（状态变为"已提货"）后，再上传质检信息');
            }
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
                ApexPages.addMessage(new ApexPages.message(ApexPages.severity.ERROR, err.getMessage()));
            }
            Database.rollback(savePot);
        }
        
    }
    
    /** 执行上传 */
    private void doUpload() {
        // 创建csv迭代器
        RMS_CSV_Iterator csvIter = new RMS_CSV_Iterator(this.fileUploadBody, this.fileCharset);
        csvIter.skipTitleLine(Csv_Fields);
        
        // 检索order前，先遍历一次csv缩小检索范围
        List<RMS_CSV_Iterator.OneLineInfo> csvTable = new List<RMS_CSV_Iterator.OneLineInfo>();
        Set<String> lfOrderCodes = new Set<String>();
        Set<String> materialCodes = new Set<String>();
        while (csvIter.next()) {
            RMS_CSV_Iterator.OneLineInfo tr = csvIter.getOneLineInfo();
            
            // 记录该行内容
            csvTable.add(tr);
            lfOrderCodes.add(tr.get('退货授权号'));
            materialCodes.add(tr.get('Material code'));
        }
        // 检索order和item
        this.queryItems(lfOrderCodes, materialCodes);
        
        // 遍历csv
        for (RMS_CSV_Iterator.OneLineInfo tr: csvTable) {
            // 通过'退货授权号'获取'OrderCode'和'BU2'
            String lfOrderCode = tr.get('退货授权号');
            String orderCode = lfOrderCode.substring(0, lfOrderCode.length()-2);
            String bu2 = lfOrderCode.substring(lfOrderCode.length()-2, lfOrderCode.length());
            
            // 检查csv内容
            if (!checkCsvValues(tr)) {
                continue;
            }
            
            // 更新order
            RTV_Order__c order = changeOrder(orderCode);
            
            // 更新item
            RTV_Order_Item__c item = changeItem(order, bu2, tr);
            if (item == null) {
                continue;
            }
            
            // 更新inspect
            changeInspect(item, tr);
        }
        
        // 创建或更新inspection
        if (!this.upsertInspects.isEmpty()) {
            // 更新order
            if (!this.updateOrders.isEmpty()) {
                update this.updateOrders.values();
            }
            // 创建item
            if (!this.upsertItems.isEmpty()) {
                upsert this.upsertItems.values();
            }
            // 创建或更新inspection
            upsert this.upsertInspects.values();
            
            // 删除csv中没有的inspect记录
            deleteOldItems();
            
            ApexPages.addMessage(new ApexPages.message(ApexPages.severity.CONFIRM, '上传成功'));
        } else {
            ApexPages.addMessage(new ApexPages.message(ApexPages.severity.ERROR, '上传失败'));
        }
    }
    
    /**
     * 统计order和item
     */
    private void queryItems(Set<String> csvLfOrderCodes, Set<String> csvMaterialCodes) {
        Set<String> soldToCodes = new Set<String>();
        
        // 检索item，统计各 LF_Order_Auth_Code__c 对应的itemlist
        for (RTV_Order_Item__c item: [
            SELECT Id, Name, LF_Order_Auth_Code__c, UniqueKey__c, Product__c,
                Material_Code__c, BU_2__c, SKU_Size_US__c, Season_Code_CN__c, Bar_Code__c,
                Application_QTY__c,
                RTV_Order__c,
                RTV_Order__r.Name,
                RTV_Order__r.Order_Auth_Code__c,
                RTV_Order__r.Status__c,
                RTV_Order__r.RTV_Defective__c,
                RTV_Order__r.Sold_To__r.Name,
                RTV_Order__r.Sold_To__r.TT_APP_ACC__c,
                RTV_Order__r.Sold_To__r.TT_FTW_EG__c,
                RTV_Order__r.Sold_To__r.TT_FW_Seasonal__c,
                (SELECT Id FROM RTV_Order_Inspections__r LIMIT 1)
            FROM RTV_Order_Item__c
            WHERE LF_Order_Auth_Code__c IN :csvLfOrderCodes
        ]) {
            // 获取order
            this.existOrders.put(item.RTV_Order__r.Order_Auth_Code__c, item.RTV_Order__r);
            
            // 获取现存的item
            this.existItems.put(item.UniqueKey__c, item);
            
            // 获取现存的inspect
            if (!item.RTV_Order_Inspections__r.isEmpty()) {
                this.existInspects.put(item.UniqueKey__c, item.RTV_Order_Inspections__r[0]);
            }
            
            soldToCodes.add(item.RTV_Order__r.Sold_To__r.Name);
        }
        
        // 检索csv中提到的Product
        for (RMS_Product__c pdt: [
            SELECT Id, Material_Code__c, Season_Code_CN__c,MSRP__c,BUCN__c
            FROM RMS_Product__c 
            WHERE Material_Code__c IN :csvMaterialCodes
        ]) {
            this.products.put(pdt.Material_Code__c + '---' + pdt.Season_Code_CN__c, pdt);
        }
        
        // 检索各个财年的TradingTerm
        for (RMS_TradingTerm__c tt: [
            SELECT TT_APP_ACC__c, TT_FW_Seasonal__c, TT_FTW_EG__c, Year__c, Name 
            FROM RMS_TradingTerm__c
            WHERE Sold_To_Code__c IN :soldToCodes
        ]) {
            tradingTerms.put(tt.Name, tt);
        }
    }
    
    /** 修改 RTV_Order__c */
    private RTV_Order__c changeOrder(String orderCode) {
        // 获取数据库中的order
        RTV_Order__c order = this.existOrders.get(orderCode);
        // 没有时报错
        if (order == null) {
            throw new RMS_CommonUtil.RMSException('未知的授权码: ' + orderCode);
        }
        // 参数指定了单个order时,不能上传其它order的内容
        if (this.theOrderId != null && this.theOrderId != order.Id) {
            throw new RMS_CommonUtil.RMSException('请只上传此授权码的订单:' + orderCode);
        }
        // 检查order状态
        if (!(new String[]{'Delivered', 'Inspected'}).contains(order.Status__c)) {
            throw new RMS_CommonUtil.RMSException('请不要上传其它状态的订单:' + order.Name + ', 状态=' + order.Status__c);
        }
        // 检查遍历过记录
        if (!this.updateOrders.containsKey(orderCode)) {
            // 添加到待更新
            this.updateOrders.put(orderCode, new RTV_Order__c(
                Id = order.Id,
                Inspect_By__c = UserInfo.getUserId(),
                Status__c = 'Inspected'
            ));
        }
        return order;
    }
    
    /** 修改 RTV_Order_Item__c */
    private RTV_Order_Item__c changeItem(RTV_Order__c order, String bu2, RMS_CSV_Iterator.OneLineInfo tr) {
        // ----------------------------
        // 检查季节码
        // ----------------------------
        RMS_CommonUtil.SeasonCodeCN season;
        try { 
            season = new RMS_CommonUtil.SeasonCodeCN(tr.get('季节码'));
        } catch(Exception err) {
            RMS_CommonUtil.pageAddMessage(ApexPages.Severity.WARNING, '(行'+tr.lineIndex+'): 季节码格式错误! 请输入正确如: "20Q1"');
            return null;
        }
        
        // ----------------------------
        // 获取item唯一键
        // ----------------------------
        RTV_Order_Item__c csvInfo = new RTV_Order_Item__c();
        csvInfo.Material_Code__c = tr.get('Material code');
        csvInfo.BU_2__c = bu2;
        csvInfo.Season_Code_CN__c = tr.get('季节码');
        
        // inseption中FW的尺码要除以10才能和packing里匹配上
        csvInfo.Sku_Size_US__c = RMS_CommonUtil.size_lfUs2Us(tr.get('Size'), csvInfo.BU_2__c);
        
        // 唯一键
        csvInfo.UniqueKey__c = RMS_CommonUtil.item_getUniqueKey(order.Order_Auth_Code__c, csvInfo);
        if(this.theOrder.Order_Type__c == 'CFS DTC Takeback' || this.theOrder.Order_Type__c == 'Digital DTC Takeback'){
            csvInfo.Bar_Code__c = tr.get('Bar code');
        }
        
        // ----------------------------
        // 新增item
        // ----------------------------
        RTV_Order_Item__c item = this.existItems.get(csvInfo.UniqueKey__c);
        if (item == null) {
            // 不允许新增时，报错
            if (createItemIfNotFound == false) {
                throw new RMS_CommonUtil.RMSException(
                    '(行'+tr.lineIndex+') 该商品不在装箱单范围中:' 
                    + '  Order=' + order.Order_Auth_Code__c
                    + ', MaterialCode=' + csvInfo.Material_Code__c
                    + ', Size=' + csvInfo.Sku_Size_US__c
                    + ', 季节码=' + csvInfo.Season_Code_CN__c
                     + '  (请确认CSV，或勾选"自动创建装箱单...")');
            }
            
            // 获取遍历过记录
            item = this.upsertItems.get(csvInfo.UniqueKey__c);
            if (item == null) {
                item = new RTV_Order_Item__c();
                
                // item.商品信息
                item.Material_Code__c = csvInfo.Material_Code__c;
                item.Material_Code__c = csvInfo.Material_Code__c;
                item.BU_2__c = csvInfo.BU_2__c;
                item.Sku_Size_US__c = csvInfo.Sku_Size_US__c;
                item.Season_Code_CN__c = csvInfo.Season_Code_CN__c;
                item.SKU_Style__c = tr.get('Style');
                item.SKU_Color__c = tr.get('Color');
                if(this.theOrder.Order_Type__c == 'CFS DTC Takeback' || this.theOrder.Order_Type__c == 'Digital DTC Takeback'){
                    item.Bar_Code__c = csvInfo.Bar_Code__c;
                }
                
                // item.商品对象信息
                RMS_Product__c pdt = this.products.get(item.Material_Code__c + '---' + item.Season_Code_CN__c);
                if (pdt == null) {
                    RMS_CommonUtil.pageAddMessage(ApexPages.Severity.WARNING, '(行'+tr.lineIndex+'): 该商品不存在');
                    return null;
                }
                item.Product__c = pdt.Id;
                item.MSRP__c = pdt.MSRP__c;
                
                // item.TradingTerm
                // 只有非C品时才获取TT
                if (tr.getDecimal('C', 0) == 0) {
                    RMS_TradingTerm__c tradeTermObj = this.tradingTerms.get(order.Sold_To__r.Name + season.fiscalYear);
                    if (tradeTermObj == null) {
                        RMS_CommonUtil.pageAddMessage(ApexPages.Severity.WARNING, '(行'+tr.lineIndex+'): 缺少该SoldTo的[TradingTerm]基础数据（财年='+season.fiscalYear+'）');
                        return null;
                    }
                    
                    item.TradeTerm__c = RMS_CommonUtil.item_getTradeTerm_TB(pdt.BUCN__c, tradeTermObj);
                    if (item.TradeTerm__c == null) {
                        RMS_CommonUtil.pageAddMessage(ApexPages.Severity.WARNING, '(行'+tr.lineIndex+'): 该SoldTo的[TradingTerm]为空白（财年='+season.fiscalYear+'）');
                        return null;
                    }
                }
                
                // item.唯一键信息
                item.RTV_Order__r = new RTV_Order__c(Order_Auth_Code__c=order.Order_Auth_Code__c);
                item.UniqueKey__c = csvInfo.UniqueKey__c;
                item.Name = RMS_CommonUtil.item_getName(item);
                
                // 加到待添加的item里
                this.upsertItems.put(item.UniqueKey__c, item);
            } 
        }
        // ----------------------------
        // 更新item
        // ----------------------------
        else {
            // 检查遍历过记录
            if (!this.upsertInspects.containsKey(item.UniqueKey__c)) {
                
                item.SKU_Style__c = tr.get('Style');
                item.SKU_Color__c = tr.get('Color');
                if(this.theOrder.Order_Type__c == 'CFS DTC Takeback' || this.theOrder.Order_Type__c == 'Digital DTC Takeback'){
                    item.Bar_Code__c = tr.get('Bar code');
                }
                
                // 添加到待更新（只添加需要更新的字段）
                this.upsertItems.put(item.UniqueKey__c, new RTV_Order_Item__c(
                    Id = item.Id,
                    UniqueKey__c = item.UniqueKey__c,
                    SKU_Style__c = item.SKU_Style__c,
                    SKU_Color__c = item.SKU_Color__c,
                    Bar_Code__c = item.Bar_Code__c
                ));
            }
        }
        return item;
    }
    
    /** 修改 RTV_Order_Inspection__c */
    private RTV_Order_Inspection__c changeInspect(RTV_Order_Item__c item, RMS_CSV_Iterator.OneLineInfo tr) {
        // 获取待更新记录
        RTV_Order_Inspection__c updInsp = this.upsertInspects.get(item.UniqueKey__c);

        if (updInsp == null) {
            // 设置空白记录 (PS:每个order都请上传完整的inspection信息)
            updInsp = new RTV_Order_Inspection__c();
            updInsp.A__c = 0;
            updInsp.B1__c = 0;
            updInsp.B2__c = 0;
            updInsp.B2_1__c = 0;
            updInsp.B3__c = 0;
            updInsp.B4__c = 0;
            updInsp.B5__c = 0;
            updInsp.B6__c = 0;
            updInsp.B7__c = 0;
            updInsp.C1__c = 0;
            updInsp.C2_1__c = 0;
            updInsp.C2_2__c = 0;
            updInsp.C2_3__c = 0;
            updInsp.C2_4__c = 0;
            updInsp.C2_5__c = 0;
            updInsp.C2_6__c = 0;
            updInsp.C2_6_1__c = 0;
            updInsp.C2_7__c = 0;
            updInsp.D__c = 0;
            updInsp.Application_QTY_A__c = 0;
            updInsp.Application_QTY_B1__c = 0;
            updInsp.Application_QTY_B2__c = 0;
            updInsp.Application_QTY_B2_1__c = 0;
            updInsp.Application_QTY_B3__c = 0;
            updInsp.Application_QTY_B4__c = 0;
            updInsp.Application_QTY_B5__c = 0;
            updInsp.Application_QTY_B6__c = 0;
            updInsp.Application_QTY_B7__c = 0;
            updInsp.Application_QTY_C1__c = 0;
            updInsp.Application_QTY_C2_1__c = 0;
            updInsp.Application_QTY_C2_2__c = 0;
            updInsp.Application_QTY_C2_3__c = 0;
            updInsp.Application_QTY_C2_4__c = 0;
            updInsp.Application_QTY_C2_5__c = 0;
            updInsp.Application_QTY_C2_6__c = 0;
            updInsp.Application_QTY_C2_6_1__c = 0;
            updInsp.Application_QTY_C2_7__c = 0;
            updInsp.Application_QTY_D__c = 0;
            updInsp.Diff_QTY_A__c = 0;
            updInsp.Diff_QTY_B1__c = 0;
            updInsp.Diff_QTY_B2__c = 0;
            updInsp.Diff_QTY_B2_1__c = 0;
            updInsp.Diff_QTY_B3__c = 0;
            updInsp.Diff_QTY_B4__c = 0;
            updInsp.Diff_QTY_B5__c = 0;
            updInsp.Diff_QTY_B6__c = 0;
            updInsp.Diff_QTY_B7__c = 0;
            updInsp.Diff_QTY_C1__c = 0;
            updInsp.Diff_QTY_C2_1__c = 0;
            updInsp.Diff_QTY_C2_2__c = 0;
            updInsp.Diff_QTY_C2_3__c = 0;
            updInsp.Diff_QTY_C2_4__c = 0;
            updInsp.Diff_QTY_C2_5__c = 0;
            updInsp.Diff_QTY_C2_6__c = 0;
            updInsp.Diff_QTY_C2_6_1__c = 0;
            updInsp.Diff_QTY_C2_7__c = 0;
            updInsp.Diff_QTY_D__c = 0;

            updInsp.Delivery_QTY_A__c = 0;
            updInsp.Delivery_QTY_B1__c = 0;
            updInsp.Delivery_QTY_B2__c = 0;
            updInsp.Delivery_QTY_B2_1__c = 0;
            updInsp.Delivery_QTY_B3__c = 0;
            updInsp.Delivery_QTY_B4__c = 0;
            updInsp.Delivery_QTY_B5__c = 0;
            updInsp.Delivery_QTY_B6__c = 0;
            updInsp.Delivery_QTY_B7__c = 0;
            updInsp.Delivery_QTY_C1__c = 0;
            updInsp.Delivery_QTY_C2_1__c = 0;
            updInsp.Delivery_QTY_C2_2__c = 0;
            updInsp.Delivery_QTY_C2_3__c = 0;
            updInsp.Delivery_QTY_C2_4__c = 0;
            updInsp.Delivery_QTY_C2_5__c = 0;
            updInsp.Delivery_QTY_C2_6__c = 0;
            updInsp.Delivery_QTY_C2_6_1__c = 0;
            updInsp.Delivery_QTY_C2_7__c = 0;
            updInsp.Delivery_QTY_D__c = 0;
            
            // 设置数据库中该inspect的id，即更新该记录
            RTV_Order_Inspection__c extInsp = this.existInspects.get(item.UniqueKey__c);
            if (extInsp != null) {
                updInsp.Id = extInsp.Id;
            }
            // 设置关联item
            updInsp.RTV_Order_Item__r = new RTV_Order_Item__c(UniqueKey__c=item.UniqueKey__c);
        }
        // 合计该inspect的Qty
        this.sumQtyOfOneInspect(updInsp, tr);
        
        // 加到待upsert记录里
        this.upsertInspects.put(item.UniqueKey__c, updInsp);
        return updInsp;
    }
    
    /** 删除csv中没有的inspection信息 */
    private void deleteOldItems() {
        List<RTV_Order_Item__c> delItems = new List<RTV_Order_Item__c>();
        List<RTV_Order_Inspection__c> delInsps = new List<RTV_Order_Inspection__c>();
        
        // 删除csv中没有的inspection信息
        for (RTV_Order_Item__c item: this.existItems.values()) {
            // 检查csv中是否有该item
            if (!this.upsertInspects.containsKey(item.UniqueKey__c)) {
                
                // 没有packing信息时，删除整个item和其下inspection
                if (item.Application_QTY__c == 0) {
                    delItems.add(item);
                } else {
                    delInsps.addAll(item.RTV_Order_Inspections__r);
                }
            }
        }
        if (!delItems.isEmpty()) { delete delItems; }
        if (!delInsps.isEmpty()) { delete delInsps; }
    }
    
    /** Inspection中各QTY字段赋值 */
    private void sumQtyOfOneInspect(RTV_Order_Inspection__c insp, RMS_CSV_Iterator.OneLineInfo tr) {
        String reasonCode = tr.get('Reason code');
        Decimal qtyA = tr.getDecimal('A', 0);
        Decimal qtyB = tr.getDecimal('B', 0);
        Decimal qtyC = tr.getDecimal('C', 0);
        Decimal qtyD = tr.getDecimal('D', 0);
        Decimal appQty = tr.getDecimal('申请数量', 0);
        Decimal diffQty = tr.getDecimal('差异', 0);
        Decimal deliveryQty = tr.getDecimal('实收', 0);
        
        if (reasonCode == 'A') { 
            insp.A__c += qtyA; 
            insp.Application_QTY_A__c += appQty;
            insp.Diff_QTY_A__c += diffQty;
            insp.Delivery_QTY_A__c += deliveryQty;
        } 
        else if (reasonCode == 'B1') { 
            insp.B1__c += qtyB; 
            insp.Application_QTY_B1__c += appQty;
            insp.Diff_QTY_B1__c += diffQty;
            insp.Delivery_QTY_B1__c += deliveryQty;
        }
        else if (reasonCode == 'B2') { 
            insp.B2__c += qtyB; 
            insp.Application_QTY_B2__c += appQty;
            insp.Diff_QTY_B2__c += diffQty;
            insp.Delivery_QTY_B2__c += deliveryQty;
        }
        else if (reasonCode == 'B2-1') { 
            insp.B2_1__c += qtyB; 
            insp.Application_QTY_B2_1__c += appQty;
            insp.Diff_QTY_B2_1__c += diffQty;
            insp.Delivery_QTY_B2_1__c += deliveryQty;
        }
        else if (reasonCode == 'B3') { 
            insp.B3__c += qtyB; 
            insp.Application_QTY_B3__c += appQty;
            insp.Diff_QTY_B3__c += diffQty;
            insp.Delivery_QTY_B3__c += deliveryQty;
        }
        else if (reasonCode == 'B4') { 
            insp.B4__c += qtyB; 
            insp.Application_QTY_B4__c += appQty;
            insp.Diff_QTY_B4__c += diffQty;
            insp.Delivery_QTY_B4__c += deliveryQty;
        }
        else if (reasonCode == 'B5') { 
            insp.B5__c += qtyB; 
            insp.Application_QTY_B5__c += appQty;
            insp.Diff_QTY_B5__c += diffQty;
            insp.Delivery_QTY_B5__c += deliveryQty;
        }
        else if (reasonCode == 'B6') { 
            insp.B6__c += qtyB; 
            insp.Application_QTY_B6__c += appQty;
            insp.Diff_QTY_B6__c += diffQty;
            insp.Delivery_QTY_B6__c += deliveryQty;
        }
        else if (reasonCode == 'B7') { 
            insp.B7__c += qtyB; 
            insp.Application_QTY_B7__c += appQty;
            insp.Diff_QTY_B7__c += diffQty;
            insp.Delivery_QTY_B7__c += deliveryQty;
        }
        else if (reasonCode == 'C1') { 
            insp.C1__c += qtyC; 
            insp.Application_QTY_C1__c += appQty;
            insp.Diff_QTY_C1__c += diffQty;
            insp.Delivery_QTY_C1__c += deliveryQty;
        }
        else if (reasonCode == 'C2-1') { 
            insp.C2_1__c += qtyC; 
            insp.Application_QTY_C2_1__c += appQty;
            insp.Diff_QTY_C2_1__c += diffQty;
            insp.Delivery_QTY_C2_1__c += deliveryQty;
        }
        else if (reasonCode == 'C2-2') { 
            insp.C2_2__c += qtyC; 
            insp.Application_QTY_C2_2__c += appQty;
            insp.Diff_QTY_C2_2__c += diffQty;
            insp.Delivery_QTY_C2_2__c += deliveryQty;
        }
        else if (reasonCode == 'C2-3') { 
            insp.C2_3__c += qtyC; 
            insp.Application_QTY_C2_3__c += appQty;
            insp.Diff_QTY_C2_3__c += diffQty;
            insp.Delivery_QTY_C2_3__c += deliveryQty;
        }
        else if (reasonCode == 'C2-4') { 
            insp.C2_4__c += qtyC; 
            insp.Application_QTY_C2_4__c += appQty;
            insp.Diff_QTY_C2_4__c += diffQty;
            insp.Delivery_QTY_C2_4__c += deliveryQty;
        }
        else if (reasonCode == 'C2-5') { 
            insp.C2_5__c += qtyC; 
            insp.Application_QTY_C2_5__c += appQty;
            insp.Diff_QTY_C2_5__c += diffQty;
            insp.Delivery_QTY_C2_5__c += deliveryQty;
        }
        else if (reasonCode == 'C2-6') { 
            insp.C2_6__c += qtyC; 
            insp.Application_QTY_C2_6__c += appQty;
            insp.Diff_QTY_C2_6__c += diffQty;
            insp.Delivery_QTY_C2_6__c += deliveryQty;
        }
        else if (reasonCode == 'C2-6-1') { 
            insp.C2_6_1__c += qtyC; 
            insp.Application_QTY_C2_6_1__c += appQty;
            insp.Diff_QTY_C2_6_1__c += diffQty;
            insp.Delivery_QTY_C2_6_1__c += deliveryQty;
        }
        else if (reasonCode == 'C2-7') { 
            insp.C2_7__c += qtyC; 
            insp.Application_QTY_C2_7__c += appQty;
            insp.Diff_QTY_C2_7__c += diffQty;
            insp.Delivery_QTY_C2_7__c += deliveryQty;
        }
        else if (reasonCode == 'D') { 
            insp.D__c += qtyD; 
            insp.Application_QTY_D__c += appQty;
            insp.Diff_QTY_D__c += diffQty;
            insp.Delivery_QTY_D__c += deliveryQty;
        }
        else if (qtyA * qtyB * qtyC * qtyD != 0) {
            throw new RMS_CommonUtil.RMSException('未知的 Reason code: ' + reasonCode);
        }
    }
    
    /** 检查CSV中该行的值 */
    private Boolean checkCsvValues(RMS_CSV_Iterator.OneLineInfo tr) {
        Boolean isOk = true;
        
        if (String.isBlank(tr.get('Material code'))) {
            RMS_CommonUtil.pageAddMessage(ApexPages.Severity.WARNING, '(行'+tr.lineIndex+'): [Material Code]不能为空');
            isOk = false;
        }
        if (String.isBlank(tr.get('Size'))) {
            RMS_CommonUtil.pageAddMessage(ApexPages.Severity.WARNING, '(行'+tr.lineIndex+'): [Size]不能为空');
            isOk = false;
        }
        if (String.isBlank(tr.get('季节码'))) {
            RMS_CommonUtil.pageAddMessage(ApexPages.Severity.WARNING, '(行'+tr.lineIndex+'): [季节码]不能为空');
            isOk = false;
        }
        return isOk;
    }
}