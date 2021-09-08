public with sharing class RTV_Defective_Upload_Inspect_DTC {
    
    // 参数:summary
    private final Id defSummaryId = Apexpages.currentPage().getParameters().get('defSummaryId');
    
    // // 对应Order
    // public final String orderId = Apexpages.currentPage().getParameters().get('orderid');
    // private RTV_Order__c order = new RTV_Order__c();
    
    // input.运行上传不存在的item
    public Boolean createItemIfNotFound {get; set;}
    
    // csv文件input
    public transient Blob fileUploadBody{get;set;}
    public String fileUploadName{get;set;}
        
    // csv编码
    public List<ApexPages.SelectOption> fileCharsetOpts {get{return RMS_CSV_Iterator.CHARSET_OPTIONS;}}
    public String fileCharset = fileCharsetOpts.get(0).getValue();
    public String getFileCharset() {return fileCharset;}
    public void setFileCharset(String value) {this.fileCharset=value;}

    // csv中必须的列
    private static String[] CSV_FIELDS = new String[]{
        '类别','客户简称','soldto','shipto','客户全称','退残编号','序号', 'MATERIAL', 'Style', 'Color', '尺码','季节码','申请数量', '退货理由（申请人）', '客/原残（申请人）', 
        '退货理由（LF）','客/原残（LF）','工厂代码', '实收数量', '可接受退货数量', 'specialcase退CC','>12M<18M','拒收件数', '拒收原因', '箱号','代码','备注', 'Bar Code'
    };
    
    // 现存的detail
    private transient Map<String, RTV_Order_Item_DEF_Detail__c> existDefDetails;
    // 现存Item
    private transient Map<String, RTV_Order_Item__c> existOrderItem;
    
    /** 基础表：tradingTerms */
    private transient Map<String, RMS_TradingTerm__c> tradingTerms;
    
    /** 基础表：常青款商品 */
    private transient Set<String> FTWCoreList;
    
    // csv中提及的product
    private transient Map<String, RMS_Product__c> csvProducts;
    
    // csv中体积的order
    private transient Map<String, RTV_Order__c> csvOrders;
    private transient Set<String> csvSoldToCodes;
    
    // 更新的列表
    private transient Map<String, RTV_Order_Item__c> upsertItems;
    private transient Map<String, RTV_Order_Item_DEF_Detail__c> upsertDefDetails;

    // 错误统计
    private transient Integer errorCnt;
    
    /** 构造方法 */
    public RTV_Defective_Upload_Inspect_DTC() {
        this.createItemIfNotFound = true;
    }
    
    /** 关闭页面 */
    public Pagereference cancel() {
        PageReference returnPage = new PageReference('/' + this.defSummaryId);
        returnPage.setRedirect(true);
        return returnPage;  
    }
    
    /** 上传 */
    public void upload() {
        // 判断文件内容是否为空
        if(this.fileUploadBody == null) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.ERROR,'No Upload Content'));
            return;
        }
        
        Savepoint savePot = Database.setSavepoint();
        try {
            // 执行上传获取更新列表
            doUpload();
            
            // 执行更新
            if (this.errorCnt == 0 && !upsertDefDetails.isEmpty()) {
                // 新增item
                if(!upsertItems.isEmpty()) {
                    upsert upsertItems.values();
                }
                
                // 新增和更新defDetail
                upsert upsertDefDetails.values();
                
                // 更新order
                this.changeOrder();
                
                // 获取更新结果
                this.queryExistDefDetails();
                RMS_CommonUtil.pageAddMessage(ApexPages.Severity.CONFIRM, '上传成功');
            } else {
                RMS_CommonUtil.pageAddMessage(ApexPages.Severity.INFO, '上传失败');
            }
        } 
        // 异常处理
        catch (Exception e) {
            RMS_CommonUtil.pageAddMessage(ApexPages.Severity.ERROR, e.getMessage());
            Database.rollback(savePot);
        }
    }
    
    /** 执行上传 */
    private void doUpload() {
        //初始化
        this.csvProducts = new Map<String,RMS_Product__c>();
        this.tradingTerms = new Map<String, RMS_TradingTerm__c>();
        this.FTWCoreList = new Set<String>();
        
        this.existDefDetails = new Map<String, RTV_Order_Item_DEF_Detail__c>();
        this.upsertDefDetails = new Map<String, RTV_Order_Item_DEF_Detail__c>();
        this.upsertItems = new Map<String,RTV_Order_Item__c>();
        this.csvOrders = new Map<String, RTV_Order__c>();
        this.csvSoldToCodes = new Set<String>();
        this.existOrderItem = new Map<String,RTV_Order_Item__c>();
        this.errorCnt = 0;
        
        // 创建csv迭代器
        RMS_CSV_Iterator csvIter = new RMS_CSV_Iterator(this.fileUploadBody, this.fileCharset);
        csvIter.skipTitleLine(CSV_FIELDS);
        
        // 第一次遍历csv，缩小检索范围
        List<RMS_CSV_Iterator.OneLineInfo> csvTable = new List<RMS_CSV_Iterator.OneLineInfo>();
        while (csvIter.next()) {
            RMS_CSV_Iterator.OneLineInfo tr = csvIter.getOneLineInfo();
            csvTable.add(tr);
            
            // 统计ordercode
            this.csvOrders.put(getOrderCode(tr.get('退残编号')), null);
            
            // 统计materialcode
            this.csvProducts.put(tr.get('MATERIAL'), null);
        }
        
        // 检索product
        this.queryProducts();
        // 检索现存的DEF_Detail
        this.queryExistDefDetails();
        // 检索现存的OrderItem
        this.queryExistOrderItem();
        // 检索TradingTerm
        this.queryTradingTerms();
        // 检索常青款商品
        this.queryFtwCoreList();
        
        // 第一次遍历csv获取数据
        for (RMS_CSV_Iterator.OneLineInfo tr: csvTable) {
            // 新增或修改detail
            this.addDefDetail(tr);
        }
    }
    
    /** 检索product */
    private void queryProducts() {
        // 检索csv中提到的Product
        for (RMS_Product__c pdt: [
            SELECT Id, Material_Code__c, Season_Code_CN__c, MSRP__c, BUCN__c
            FROM RMS_Product__c 
            WHERE Material_Code__c IN :this.csvProducts.KeySet()
        ]) {
            this.csvProducts.put(pdt.Material_Code__c + '---' + pdt.Season_Code_CN__c, pdt);
        }
    }

    /** 检索Order和Item */
    private void queryExistOrderItem() {
        // order
        for (RTV_Order__c order: [
            SELECT Id, Order_Auth_Code__c, Ship_To__c,
                Sold_To__c, 
                Sold_To__r.Name,
                Sold_To__r.TT_APP_ACC__c,
                Sold_To__r.TT_FW_Seasonal__c,
                Sold_To__r.TT_FTW_EG__c
            FROM RTV_Order__c
            WHERE RTV_DEF_Summary__c = :this.defSummaryId
            AND Order_Auth_Code__c IN :this.csvOrders.KeySet()
            AND Status__c IN ('Delivered', 'Inspected')
        ]) {
            this.csvOrders.put(order.Order_Auth_Code__c, order);
            this.csvSoldToCodes.add(order.Sold_To__r.Name);
        }
        
        // item
        for (RTV_Order_Item__c orderItem: [
            SELECT Id, UniqueKey__c,application_QTY__c
            FROM RTV_Order_Item__c 
            WHERE RTV_Order__r.RTV_DEF_Summary__c = :this.defSummaryId
            AND RTV_Order__r.Order_Auth_Code__c IN :this.csvOrders.KeySet()
            AND RTV_Order__r.Status__c IN ('Delivered', 'Inspected')
        ]) {
            this.existOrderItem.put(orderItem.UniqueKey__c, orderItem);
        }
    }
    
    /** 检索现存的DEF_Detail */
    private void queryExistDefDetails() {
        for (RTV_Order_Item_DEF_Detail__c detail: [
            SELECT Id,Name,Defective_Reason_LF__c, Defective_Source_LF__c, Actual_QTY__c,
                Specialcase_DEF_CC__c,Box_Code__c,Remarks__c,Detail_Number__c,
                Factory_Code__c, Delivery_QTY__c, Acceptable_Return_QTY__c,
                Reject_QTY__c, Reject_Reason__c, Code__c,
                Material_Code__c,
                RTV_Order_Item__c,
                RTV_Order_Item__r.UniqueKey__c,
                RTV_Order_Item__r.Material_Code__c,
                RTV_Order_Item__r.BU_2__c,
                RTV_Order_Item__r.Sku_Size_US__c,
                RTV_Order_Item__r.Defective_Box_Code__c,
                RTV_Order_Item__r.Defective_Source__c,
                RTV_Order_Item__r.Defective_Reason__c,
                RTV_Order_Item__r.IsMaterial__c,
                RTV_Order_Item__r.RTV_Order__c,
                RTV_Order_Item__r.RTV_Order__r.Order_Auth_Code__c
            FROM RTV_Order_Item_DEF_Detail__c
            WHERE RTV_Order_Item__r.RTV_Order__r.RTV_DEF_Summary__c = :this.defSummaryId
            ORDER BY Detail_Number__c
        ]) {
            this.existDefDetails.put(detail.RTV_Order_Item__r.RTV_Order__r.Order_Auth_Code__c + '##' + detail.Detail_Number__c, detail);
        }
    }
    
    /** 检索各个财年的TradingTerm */
    private void queryTradingTerms() {
        for (RMS_TradingTerm__c tt: [
            SELECT TT_APP_ACC__c, TT_FW_Seasonal__c, TT_FTW_EG__c, Year__c, Name 
            FROM RMS_TradingTerm__c
            WHERE Sold_To_Code__c IN :this.csvSoldToCodes
        ]) {
            this.tradingTerms.put(tt.Name, tt);
        }
    }
    
    /** 检索常青款商品 */
    private void queryFtwCoreList() {
        for (RMS_FTW_Core_List__c ftwCore: [
            SELECT id, Name
            FROM RMS_FTW_Core_List__c 
            WHERE Name IN :this.csvProducts.KeySet()
        ]) {
            this.FTWCoreList.add(ftwCore.Name.toUpperCase());
        }
    }
    
    /** 更新DEF_Detail */
    private void addDefDetail(RMS_CSV_Iterator.OneLineInfo tr) {
        RTV_Order_Item_DEF_Detail__c detail = new RTV_Order_Item_DEF_Detail__c();
        
        // -------------------------------------
        // 获取order
        // -------------------------------------
        String orderCode = getOrderCode(tr.get('退残编号'));
        RTV_Order__c order = this.csvOrders.get(orderCode);
        if (order == null) {
            this.errorCnt ++;
            RMS_CommonUtil.pageAddMessage(ApexPages.Severity.WARNING, '无法找到该订单: ' + orderCode);
            return;
        }
        
        // -------------------------------------
        // 排除重复记录
        // -------------------------------------
        String detailKey = order.Order_Auth_Code__c + '##' +  tr.get('序号');
        if (this.upsertDefDetails.containsKey(detailKey)) {
            this.errorCnt ++;
            RMS_CommonUtil.pageAddMessage(ApexPages.Severity.WARNING, 
                '[行'+tr.lineIndex+'] 序号重复'
                + ': 退残编号=' + order.Order_Auth_Code__c
                + ', 序号=' + tr.get('序号'));
            return;
        }
        
        // -------------------------------------
        // 检查商品
        // -------------------------------------
        RMS_Product__c product = this.csvProducts.get(tr.get('MATERIAL') + '---' + tr.get('季节码'));
        
        // -------------------------------------
        // 检查商品Style和Color
        // -------------------------------------
        if (String.isBlank(tr.get('Style'))) {
            this.errorCnt ++;
            RMS_CommonUtil.pageAddMessage(ApexPages.Severity.WARNING, '[行'+tr.lineIndex+'] 请填写 "Style"');
            return;
        }
        if (String.isBlank(tr.get('Color')) && tr.get('类别').startsWith('A')) {
            this.errorCnt ++;
            RMS_CommonUtil.pageAddMessage(ApexPages.Severity.WARNING, '[行'+tr.lineIndex+'] 请填写 "Color"');
            return;
        }
        
        // 检查常青款
        Boolean isFwCore = this.FTWCoreList.contains(tr.get('MATERIAL').toUpperCase());
        
        // -------------------------------------
        // 创建DefDetail
        // -------------------------------------
        RTV_Order_Item_DEF_Detail__c existDetail = this.existDefDetails.get(detailKey);
        if (existDetail == null) {
            if (createItemIfNotFound == false) {
                this.errorCnt ++;
                RMS_CommonUtil.pageAddMessage(ApexPages.Severity.WARNING, 
                    '[行'+tr.lineIndex+'] 该商品不在装箱单范围中:' 
                    + ': Order=' + order.Order_Auth_Code__c
                    + ', MATERIAL=' + tr.get('MATERIAL')
                    + ', Size=' + tr.get('尺码')
                    + ', 季节码=' +tr.get('季节码')
                    + ', 箱号=' +tr.get('箱号')
                    + ', 序号=' + tr.get('序号')
                );
                return;
            }
            // 更新item
            RTV_Order_Item__c item = this.createItem(order, product, isFwCore, tr);
            
            // 创建item下的detail
            detail = new RTV_Order_Item_DEF_Detail__c();
            detail.RTV_Order_Item__r = new RTV_Order_Item__c(UniqueKey__c=item.UniqueKey__c);
            detail.Material_Code__c = tr.get('MATERIAL');
            detail.SKU_Size_US__c = tr.get('尺码');
            detail.Season_Code_CN__c = tr.get('季节码');
            detail.BU_2__c = tr.get('类别');
            detail.Sold_To__c = order.Sold_To__c;
            detail.Ship_To__c = order.Ship_To__c;
            detail.Customer_Abbreviation__c = tr.get('客户简称');
            detail.Customer_Name__c = tr.get('客户全称');
            detail.Order_Auth_Code__c = tr.get('退残编号');
            detail.Detail_Number__c = Decimal.valueOf(tr.get('序号'));
            detail.Defective_Reason__c = tr.get('退货理由（申请人）');
            detail.Defective_Source__c = tr.get('客/原残（申请人）');
            detail.Name = tr.get('序号');
            detail.Application_QTY__c = 0;
            detail.isDiff__c = true;
        } 
        // -------------------------------------
        // 更新DefDetail
        // -------------------------------------
        else {
            // 更新item
            this.updateItem(existDetail.RTV_Order_Item__r, product, isFwCore, tr);
            // 设置detail.Id
            detail.Id = existDetail.Id;
        }
        
        // -------------------------------------
        // 设置DefDetail里的inspect信息
        // -------------------------------------
        detail.Factory_Code__c = tr.get('工厂代码');
        detail.Defective_Reason_LF__c = tr.get('退货理由（LF）');
        detail.Defective_Source_LF__c = tr.get('客/原残（LF）');
        detail.Actual_QTY__c = tr.getDecimal('实收数量', 0);
        detail.FactoryReturnQTY__c = tr.getDecimal('实际退工厂数量', 0);
        detail.Destroy_QTY__c = tr.getDecimal('销毁数量', 0);
        detail.Acceptable_Return_QTY__c = tr.getDecimal('可接受退货数量', 0);
        detail.Specialcase_DEF_CC__c = tr.get('specialcase退CC');
        detail.DEF_12M_18M__c = tr.get('>12M<18M');
        detail.Reject_QTY__c = tr.getDecimal('拒收件数', 0);
        detail.Reject_Reason__c = tr.get('拒收原因');
        detail.Box_Code__c = tr.get('箱号');
        detail.Code__c = tr.get('代码');
        detail.Remarks__c = tr.get('备注');

        // 添加到待更新list
        this.upsertDefDetails.put(detailKey, detail);
    }
    
    /** 新增或更新item */
    private RTV_Order_Item__c createItem(RTV_Order__c order, 
        RMS_Product__c product,
        Boolean isFwCore,
        RMS_CSV_Iterator.OneLineInfo tr
    ) {
        // 创建item
        RTV_Order_Item__c item = new RTV_Order_Item__c();
        
        // item.基础信息
        item.Material_Code__c = tr.get('MATERIAL');
        item.BU_2__c = tr.get('类别');
        item.Sku_Size_US__c = tr.get('尺码');
        item.Season_Code_CN__c = tr.get('季节码');
        item.Defective_Box_Code__c = tr.get('箱号');
        
        // item.申请时的备注(无实物退残)
        item.Application_Remark__c = tr.get('备注');
        item.IsMaterial__c = RMS_CommonUtil.item_Def_IsNoDelivery(item.Application_Remark__c);
        item.IsSpecialDEF__c = RMS_CommonUtil.item_Def_IsSepical(item.Application_Remark__c);
        
        // item.退货理由
        item.Defective_Reason__c = tr.get('退货理由（申请人）');
        if (String.isBlank(item.Defective_Reason__c)) {
            item.Defective_Reason__c = tr.get('退货理由（LF）');
        }
        if (String.isBlank(item.Defective_Reason__c)) {
            this.errorCnt ++;
            RMS_CommonUtil.pageAddMessage(ApexPages.Severity.WARNING, '[行'+tr.lineIndex+'] 请填写 "退货理由"');
            return null;
        }
        
        // item.原残/客残
        item.Defective_Source__c = tr.get('客/原残（申请人）');
        item.Application_QTY__c = 0;
        
        // item.商品信息
        if (product != null) {
            item.Product__c = product.Id;
            item.SKU_BU__c = product.BUCN__c;
        }
        
        // item.Style和Color
        item.SKU_Style__c = tr.get('Style');
        item.SKU_Color__c = tr.get('Color');
        item.Bar_Code__c = tr.get('Bar Code');
        
        // item.唯一信息
        Integer num = Integer.valueOf(tr.get('序号'));
        item.UniqueKey__c = RMS_CommonUtil.item_getUniqueKeyDef(order.Order_Auth_Code__c, item, num, num);
        item.RTV_Order__r = new RTV_Order__c(Order_Auth_Code__c=order.Order_Auth_Code__c);
        item.Name = RMS_CommonUtil.item_getName(item);
            
        // 添加到新增itemList
        upsertItems.put(item.UniqueKey__c, item);
        return item;
    }
    
    /** 新增或更新item */
    private RTV_Order_Item__c updateItem(RTV_Order_Item__c item, 
        RMS_Product__c product,
        Boolean isFwCore,
        RMS_CSV_Iterator.OneLineInfo tr
    ) {
        RTV_Order_Item__c updItem = new RTV_Order_Item__c();
        updItem.Id = item.Id;
        
        // item.季节码
        updItem.Season_Code_CN__c = tr.get('季节码');
        
        // item.Style和Color
        updItem.SKU_Style__c = tr.get('Style');
        updItem.SKU_Color__c = tr.get('Color');
        updItem.Bar_Code__c = tr.get('Bar Code');
        updItem.SKU_Size_US__c = tr.get('尺码');
        updItem.POS_SKU__c = tr.get('POS SKU');
        // item.商品信息
        if (product != null) {
            updItem.Product__c = product.Id;
            updItem.SKU_BU__c = product.BUCN__c;
        }
        
        upsertItems.put(item.id, updItem);
        return updItem;
    }
    
    /** 修改 RTV_Order__c */
    private void changeOrder() {
        // 更新order
        List<RTV_Order__c> updOrders = new List<RTV_Order__c>();
        for (RTV_Order__c order: this.csvOrders.values()) {
            if (order != null) {
                RTV_Order__c updO = new RTV_Order__c();
                updO.Id = order.Id;
                updO.Inspect_By__c = UserInfo.getUserId();
                updO.Status__c = 'Inspected';
                updOrders.add(updO);
            }
        }
        update updOrders;
    }
    
    /** 获取orderCode */
    private static String getOrderCode(String lfOrderCode) {
        return lfOrderCode.substring(0, lfOrderCode.length()-2);
    }
}