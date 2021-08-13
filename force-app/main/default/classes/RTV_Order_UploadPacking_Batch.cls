public with sharing class RTV_Order_UploadPacking_Batch 
implements Database.Batchable<RMS_CSV_Iterator.OneLineInfo>, Database.Stateful {
    /** 参数：summaryId */
    public RTV_Summary__c summary;
    
    /** 参数: 画面选择的shipto */
    public String selectShipTo;
    
    /** 参数：shipto白名单 */
    public Map<String, RTV_RP_Ship_To__c> shipToWhiteList;
    
    /** 参数：CSV内容 */
    public Blob csvFileBody;
    public String csvFileCharset;
    
    /** 静态参数：CSV必填列 */
    private static final String[] CSV_FIELDS = new String[]{
        '箱号','货品号', 'BU', '尺寸(美码)', '尺寸(亚码)', '季节码', '数量','授权码', 'Sold To', 'Ship To', '最早提货日'
    };
    
    /** 执行信息 */
    private Datetime batchStartTime;
    
    /** 返回错误信息 */
    private Boolean isError = false;
    private Boolean isDownloadErrorCsv = false;
    private String resErrorCsv = RMS_CSV_Iterator.UTF8_BOM; //返回的csv以utf8BOM开头
    
     /** 检索: 基础表.尺码 */
     private Map<String, List<String>> usSizeMap = new Map<String, List<String>>();
     
     /** 检索: 基础表.各财年的TradingTerm */
     private Map<String, RMS_TradingTerm__c> tradingTerms = new Map<String, RMS_TradingTerm__c>();
     
     /** 全局统计：所有新增的item（用于检查重复数据） */
     private Set<String> allNewPackings = new Set<String>();
     private Map<String, RTV_Order_Item__c> allNewItems = new Map<String, RTV_Order_Item__c>();
     
     /** 全局统计：用于检查混箱 */
     private Map<String, String> boxCodeToBU = new Map<String, String>();
     
     /** 全局统计：各订单各BU的箱数 */
     private Map<String, BUBoxes> totalOrderBoxes = new Map<String, BUBoxes>();
     
     /** 单个excute中的统计 */
     public class OneExecuteInfo {
        Set<String> csvMaterials = new Set<String>();
        Set<String> csvShipTos = new Set<String>();
        
        /** 检索: 现存的order */
        Map<String, RTV_Order__c> existOrders = new Map<String, RTV_Order__c>();
        
        /** 检索: 商品白名单 */
        Map<String, MaterialInfo> skuWhiteList = new Map<String, MaterialInfo>();
        
        /** 待新增/更新的order和item */
        Map<String, RTV_Order__c> upsertOrders = new Map<String, RTV_Order__c>();
        Map<String, RTV_Order_Item__c> upsertItems = new Map<String, RTV_order_Item__c>();
        Map<String, RTV_Order_Packing__c> insertPackings = new Map<String, RTV_Order_Packing__c>();
        Set<Id> clearOrderIds = new Set<Id>();
     }
    
    /** 开始 */
    public Iterable<RMS_CSV_Iterator.OneLineInfo> start(Database.BatchableContext context) {
        this.batchStartTime = System.now();
        
        // 检索现存数据
        this.queryUSSize();
        this.queryTradingTerms();
        
        // 创建CSV迭代器
        RMS_CSV_Iterator iter = new RMS_CSV_Iterator(this.csvFileBody, this.csvFileCharset);
        iter.skipTitleLine(CSV_FIELDS);
        this.resErrorCsv += iter.headerLine + ',错误描述';
        
        // 返回csv可迭代对象
        return new RMS_CSV_Iterator.BatchIterable(iter);
    }
    
    /** 执行 */
    public void execute(Database.BatchableContext context, List<RMS_CSV_Iterator.OneLineInfo> trs) {
        OneExecuteInfo oneExe = new OneExecuteInfo();
        
        // 遍历缩小检索范围
        for (RMS_CSV_Iterator.OneLineInfo tr: trs) {
            oneExe.csvShipTos.add(tr.get('Ship To'));
            oneExe.csvMaterials.add(tr.get('货品号'));
        }
        // 检索order和sku白名单
        this.querySkuWL(oneExe);
        this.queryOrders(oneExe);
        
        // 遍历添加item
        for (RMS_CSV_Iterator.OneLineInfo tr: trs) {
            this.resErrorCsv += '\r\n' + tr.line + ',';
            
            // 检查shipto
            if (this.selectShipTo != 'from_csv' && this.selectShipTo !=  tr.get('Ship To')) {
                this.isError = true;
                this.resErrorCsv += '上传指定的Ship to与CSV中不符！';
                continue;
            }
            // 检查shipTo白名单
            RTV_RP_Ship_To__c shipToWL = this.shipToWhiteList.get(tr.get('Ship To').toUpperCase());
            if (shipToWL == null) {
                this.isError = true;
                this.resErrorCsv += 'Ship to不在召回范围内！';
                continue;
            }
            
            // 更新或新增Order
            RTV_Order__c order = this.getOrNewOrder(oneExe, shipToWL, tr);
            if (order == null) { 
                continue;
            }
            // 新建item
            this.newItem(oneExe, order, shipToWL.Ship_To__r, tr);
        }
        // 没有错误时更新
        if (this.isError == false 
        && oneExe.upsertOrders.size() > 0 
        && oneExe.upsertItems.size() > 0) {
            try {
                // 统计箱数，更新order
                for (String shipToCode : oneExe.upsertOrders.keySet()) {
                    RTV_Order__c upsOrder = oneExe.upsertOrders.get(shipToCode);
                    BUBoxes buBox = this.totalOrderBoxes.get(shipToCode);
                    if(buBox != null){
                        upsOrder.AP_Boxes__c = buBox.APBoxes.size();
                        upsOrder.AC_Boxes__c = buBox.ACBoxes.size();
                        upsOrder.FW_Boxes__c = buBox.FWBoxes.size();
                    }
                    System.debug('## 创建/更新Order: ' + upsOrder.Name);
                }
                upsert oneExe.upsertOrders.values();
                
                // 删除旧的item
                if (oneExe.clearOrderIds.size() > 0) {
                    delete [
                        SELECT Id FROM RTV_Order_Item__c
                        WHERE RTV_Order__c IN :oneExe.clearOrderIds 
                        AND CreatedDate < :this.batchStartTime
                    ];
                }
                
                // 新建item
                upsert oneExe.upsertItems.values();
                insert oneExe.insertPackings.values();
                
                // 统计新增的item的id，用于检查重复数据
                for (RTV_Order_Item__c item: oneExe.upsertItems.values()) {
                    this.allNewItems.get(item.UniqueKey__c).Id = item.Id;
                }
            }
            // 异常处理
            catch(DmlException err) {
                String dmlErrMsg = err.getDmlMessage(0);

                // 如果是自定义验证错误，只截取抛出错误描述
                if (dmlErrMsg.contains('FIELD_CUSTOM_VALIDATION_EXCEPTION')) {
                    String subDmlErrMsg = dmlErrMsg
                        .substringAfterLast('FIELD_CUSTOM_VALIDATION_EXCEPTION,')
                        .substringBeforeLast(': []');
                    throw new RMS_CommonUtil.RMSException(subDmlErrMsg);
                }
                throw new RMS_CommonUtil.RMSException(dmlErrMsg);
            }
        }
    }
    
    /** 检索现存的order */
    public void queryOrders(OneExecuteInfo oneExe) {
        for (RTV_Order__c order: [
            SELECT Id, Name, Order_Auth_Code__c, Status__c,
                Ship_To__c, Ship_To__r.Name, Ship_To__r.Code_Add__c,
                Ship_To__r.Sold_To_Code__r.Id,
                Ship_To__r.Sold_To_Code__r.TT_APP_ACC__c, 
                Ship_To__r.Sold_To_Code__r.TT_FTW_EG__c, 
                Ship_To__r.Sold_To_Code__r.TT_FW_Seasonal__c
            FROM RTV_Order__c 
            WHERE Return_Summary__c = :this.summary.Id
            AND Ship_To__r.Name IN :oneExe.csvShipTos
        ]) {
            oneExe.existOrders.put(order.Ship_To__r.Name.toUpperCase(), order);
        }
    }
    
    /** 检索sku白名单(每次上传前检索) */
    private void querySkuWL(OneExecuteInfo oneExe) {
        
        // 检索program.skuBudget，并统计到map里
        for (RTV_RP_Sku_Budget__c skuBudget: [
            SELECT Sku_Material_Code__c, 
                Budget_QTY__c, Budget_MSRP__c, Budget_NET__c,
                RP_Ship_To__c, 
                RP_Ship_To__r.Ship_To__r.Name,
                Sold_To__c, 
                Sold_To__r.Name,
                Account_Group__c, 
                Account_Group__r.Name
            FROM RTV_RP_SKU_Budget__c 
            WHERE Return_Program__c = :this.summary.RTV_Program__c 
            AND Sku_Material_Code__c IN :oneExe.csvMaterials
            AND (RP_Ship_To__c = null OR RP_Ship_To__r.Ship_To__r.Name IN :oneExe.csvShipTos)
        ]) {
            String material = skuBudget.Sku_Material_Code__c;
            
            // 统计该materialCode的预算信息
            MaterialInfo materialInfo = oneExe.skuWhiteList.get(material.toUpperCase());
            if (materialInfo == null) {
                materialInfo = new MaterialInfo();
            }
            
            // shipTo级别的预算
            if (skuBudget.RP_Ship_To__c != null) {
                materialInfo.shipToBudgets.put(skuBudget.RP_Ship_To__r.Ship_To__r.Name, skuBudget);
            }
            // soldTo级别的预算
            else if (skuBudget.Sold_To__c != null) {
                materialInfo.soldToBudgets.put(skuBudget.Sold_To__r.Name, skuBudget);
            }
            // accountGroup级别的预算
            else if (skuBudget.Account_Group__c != null) {
                materialInfo.accGroupBudgets.put(skuBudget.Account_Group__r.Name, skuBudget);
            }
            // 全局预算
            else {
                materialInfo.globalBudget = skuBudget;
            }
            oneExe.skuWhiteList.put(material.toUpperCase(), materialInfo);
        }
        
        // 检索基础product表，并统计到map里
        for (RMS_Product__c pdt: [
            SELECT Id, Name, Material_Code__c, Season_Code_CN__c, BU__c, BUCN__c, MSRP__c,Size_Range__c,FOB_CNY__c,	FOB_USD__c,FOB_Rate__c
            FROM RMS_Product__c
            WHERE Material_Code__c IN :oneExe.skuWhiteList.keySet()
            AND Material_Code__c IN :oneExe.csvMaterials
        ]) {
            MaterialInfo materialInfo = oneExe.skuWhiteList.get(pdt.Material_Code__c.toUpperCase());
            materialInfo.products.add(pdt);
        }
    }
    
    /** 检索美码表 */
    private void queryUSSize() {
        for(RMS_US_Size__c usSize:[
            SELECT BU__c, Size__c FROM RMS_US_Size__c
        ]) {
            String bu = usSize.BU__c.startsWith('F')? 'FW': usSize.BU__c;
            if(usSizeMap.containsKey(bu)) {
                usSizeMap.get(bu).add(usSize.Size__c);
            } else {
                List<String> size = new List<String>();
                size.add(usSize.Size__c);
                usSizeMap.put(bu, size);
            }
        }
    }
    
    /** 检索各个财年的TradingTerm */
    private void queryTradingTerms() {
        this.tradingTerms = new Map<String, RMS_TradingTerm__c>();
        
        for (RMS_TradingTerm__c tt: [
            SELECT TT_APP_ACC__c, TT_FW_Seasonal__c, TT_FTW_EG__c, Year__c, Name 
            FROM RMS_TradingTerm__c
        ]) {
            this.tradingTerms.put(tt.Name, tt);
        }
    }
    
    // 更新或新增Order
    public RTV_Order__c getOrNewOrder(OneExecuteInfo oneExe, RTV_RP_Ship_To__c shipToWL, RMS_CSV_Iterator.OneLineInfo tr) {
        RMS_Ship_To__c shipTo = shipToWL.Ship_To__r;
        
        // 不存在时新建order
        RTV_order__c order = oneExe.existOrders.get(shipTo.Name.toUpperCase());
        if (order == null) {
            
            // 不在待新建order里时，即相同order取第一行
            order = oneExe.upsertOrders.get(shipTo.Name.toUpperCase());
            if (order == null) {
                // 基础信息
                order = new RTV_Order__c();
                order.Return_Summary__c = summary.Id;
                order.Sold_To__c = shipTo.Sold_To_Code__r.Id;
                order.Ship_To__c = shipTo.Id;
                
                // 唯一键信息
                order.Name = shipToWL.Order_Auth_Code__c;
                order.Order_Auth_Code__c = order.Name;
                order.Ship_To_Address__c = shipTo.Code_Add__c;
                
                // owner
                order.OwnerId = shipTo.OwnerId;
                
                // 最早提货日
                order.Earliest_Delivery_Date__c = RMS_CommonUtil.str2Date(tr.get('最早提货日'));
                if (order.Earliest_Delivery_Date__c <= Date.today()) {
                    this.isError = true;
                    this.resErrorCsv += '最早提货日必须在系统日期的第二天或以后';
                    return null;
                }
                // 默认使用shipTo的提货人信息
                order.Ship_To_Contact__c = shipTo.Contact_Pr__c;
                order.Ship_To_Phone1__c = shipTo.Contact_Tel1__c;
                order.Ship_To_Phone2__c = shipTo.Contact_Tel2__c;
                order.Ship_To_Address__c = shipTo.Dely_Addr__c;
                
                // 添加到待更新
                oneExe.upsertOrders.put(shipTo.Name.toUpperCase(), order);
            }
        }
        // 存在时更新order
        else {
            // 检查order
            if(order.Status__c == 'POST to LF') {
                this.isError = true;
                this.resErrorCsv += '该ship to已经开始提货';
                return null;
            }
            // 获取待更新order
            if (!oneExe.upsertOrders.containsKey(shipTo.Name.toUpperCase())) {
                RTV_Order__c upsOrder = new RTV_Order__c();
                upsOrder.Id = order.Id;
                
                // 最早提货日
                upsOrder.Earliest_Delivery_Date__c = RMS_CommonUtil.str2Date(tr.get('最早提货日'));
                if (upsOrder.Earliest_Delivery_Date__c <= Date.today()) {
                    this.isError = true;
                    this.resErrorCsv += '最早提货日必须在系统日期的第二天或以后';
                    return null;
                }
                // 默认使用shipTo的提货人信息
                upsOrder.Ship_To_Contact__c = shipTo.Contact_Pr__c;
                upsOrder.Ship_To_Phone1__c = shipTo.Contact_Tel1__c;
                upsOrder.Ship_To_Phone2__c = shipTo.Contact_Tel2__c;
                upsOrder.Ship_To_Address__c = shipTo.Dely_Addr__c;
                
                // 添加到待更新
                oneExe.upsertOrders.put(shipTo.Name.toUpperCase(), upsOrder);
                oneExe.clearOrderIds.add(upsOrder.Id);
            }
        }
        return order;
    }
    
    // 添加新的item
    public void newItem(OneExecuteInfo oneExe, RTV_Order__c order, RMS_Ship_To__c shipTo, RMS_CSV_Iterator.OneLineInfo tr) {
        // ----------------------------
        // item.基础信息
        // ----------------------------
        RTV_Order_Item__c item = new RTV_Order_Item__c();
        item.Material_Code__c = tr.get('货品号');
        item.BU_2__c = RMS_CommonUtil.item_getBu2(tr.get('BU'));
        item.Season_Code_CN__c = tr.get('季节码');
        
        // ----------------------
        // 检查尺码
        // ----------------------
        item.SKU_Size_US__c = tr.get('尺寸(美码)').toUpperCase();
        item.SKU_Size_Asia__c = tr.get('尺寸(亚码)').toUpperCase();
        
        // 美码没有填写时，使用亚码计算美码
        if (String.isBlank(item.SKU_Size_US__c)) {
            item.SKU_Size_US__c = RMS_CommonUtil.size_Asia2Us(item.SKU_Size_Asia__c, item.BU_2__c);
        } 
        // 亚码没有填写时，使用美码计算亚码
        else if (String.isBlank(item.SKU_Size_Asia__c)) {
            item.SKU_Size_Asia__c = RMS_CommonUtil.size_Asia2Us(item.SKU_Size_US__c, item.BU_2__c);
        }
        
        // ----------------------------
        // 校验授权码（上传的授权码去掉后两位BU）
        // ----------------------------
        String csvOrderCodeBu = tr.get('授权码');
        String csvOrderCode = csvOrderCodeBu.substring(0, csvOrderCodeBu.length()-2);
        if(csvOrderCode != order.Name) {
            this.isError = true;
            this.resErrorCsv += '授权码不正确！';
            return;
        }

        // ----------------------------
        // AC/AP 和 FW 不能混装
        // ----------------------------
        if(boxCodeToBU.containsKey(tr.get('箱号')+order.name)) {
            if(boxCodeToBU.get(tr.get('箱号')+order.name) != item.BU_2__c.substring(0, 1)) {
                this.isError = true;
                this.resErrorCsv += '不同BU存在混箱包装，必须拆箱！';
                return;
            }     
        } else {
            boxCodeToBU.put(tr.get('箱号')+order.name, item.BU_2__c.substring(0, 1));
        }
        
        // ----------------------------
        // 检查季节码
        // ----------------------------
        RMS_CommonUtil.SeasonCodeCN season;
        try { 
            season = new RMS_CommonUtil.SeasonCodeCN(item.Season_Code_CN__c);
        } catch(Exception err) {
            this.isError = true;
            this.resErrorCsv += '季节码格式错误! 请输入正确如: "20Q1"';
            return;
        }
        
        // ----------------------------
        // item.商品信息
        // ----------------------------
        MaterialInfo materialInfo = oneExe.skuWhiteList.get(item.Material_Code__c.toUpperCase());
        RTV_RP_Sku_Budget__c skuBudget;
        RMS_Product__c pdt;
        
        // 检查货品号是否在召回范围内
        if (materialInfo == null) {
            this.isError = true;
            this.resErrorCsv += '货品号不在召回范围内！';
            return;
        }
        if ((skuBudget = materialInfo.getSkuBudget(shipTo)) == null) {
            this.isError = true;
            this.resErrorCsv += '货品号不在该ShipTo的召回范围内！';
            return;
        }
        
        // 获取商品信息
        if ((pdt = materialInfo.getProduct(item.Season_Code_CN__c, tr.get('BU'))) == null) {
            this.isError = true;
            this.resErrorCsv += '该商品的季节码错误！';
            return;
        }
        
        // 检查尺寸(美码), 出错提示该商品的size range
        if(this.usSizeMap.containsKey(item.BU_2__c)) {
            if(!this.usSizeMap.get(item.BU_2__c).contains(item.SKU_Size_US__c)) {
                this.isError = true;
                String okSizeRange = pdt.Size_Range__c == null? '': pdt.Size_Range__c.replace('-', '~');
                this.resErrorCsv += '美码尺寸错误！ 正确的尺码范围：' + okSizeRange;
                return;
            }
        }
        item.Product__c = pdt.Id;
        item.SKU_Budget__c = skuBudget.Id;
        item.SKU_BU__c = pdt.BUCN__c;
        
        // -----------------------------
        // 获取该财年的tradingTerm
        // -----------------------------
        RMS_TradingTerm__c tradeTermObj = this.tradingTerms.get(shipTo.Sold_To_Code__r.Name + season.fiscalYear);
        if (tradeTermObj == null) {
            this.isError = true;
            this.resErrorCsv += '缺少该SoldTo的[TradingTerm]基础数据（财年='+season.fiscalYear+'）';
            return;
        }
        item.TradeTerm__c = RMS_CommonUtil.item_getTradeTerm_TB(pdt.BUCN__c, tradeTermObj);
        if (item.TradeTerm__c == null) {
            this.isError = true;
            this.resErrorCsv += '该SoldTo的[TradingTerm]为空白（财年='+season.fiscalYear+'）';
            return;
        }
        
        // ----------------------------
        // item.数量和单价
        // ----------------------------
        item.Application_QTY__c = Double.valueOf(tr.get('数量'));
        item.MSRP__c = pdt.MSRP__c;
        item.NET__c = RMS_CommonUtil.item_getNet(pdt, summary.RTV_Program__r, item.TradeTerm__c);
        item.Application_Amount__c = item.Application_QTY__c * item.NET__c;
        item.FOB_USD__c = pdt.FOB_USD__c;
        item.FOB_CNY__c = pdt.FOB_CNY__c;
        item.FOB_Rate__c = pdt.FOB_Rate__c;

        // ----------------------------
        // item.名称和唯一键
        // ----------------------------
        item.Name = RMS_CommonUtil.item_getName(item);
        item.UniqueKey__c = RMS_CommonUtil.item_getUniqueKey(order.Order_Auth_Code__c, item);
        item.RTV_Order__r = new RTV_Order__c(Order_Auth_Code__c=order.Order_Auth_Code__c);
        
        // 检查重复的item（授权码+货品号+sku+季节码）
        RTV_Order_Item__c addedItem = this.allNewItems.get(item.UniqueKey__c);
        if (addedItem != null) {
            // 在之前execute中已新增的item，设上id进行更新操作
            if (addedItem.Id != null) {
                item.Id = addedItem.Id;
            }
            // 合计数量
            item.Application_QTY__c += addedItem.Application_QTY__c;
            item.Application_Amount__c = item.Application_QTY__c * item.NET__c;
        }
        this.allNewItems.put(item.UniqueKey__c, item);
        
        // 添加item到待更新
        oneExe.upsertItems.put(item.UniqueKey__c, item);
        
        // 添加新的item.packingDetail
        this.newItemPackings(oneExe, item, tr, shipTo.Name.toUpperCase());
        
        System.debug('## 创建/更新item: ' + item.UniqueKey__c);
    }
    
    /** 添加新的item.packingDetail */
    public void newItemPackings(OneExecuteInfo oneExe, RTV_Order_Item__c item, RMS_CSV_Iterator.OneLineInfo tr, String shiptoCode) {
        // packingDetail
        RTV_Order_Packing__c pkg = new RTV_Order_Packing__c();
        pkg.Box_Code__c = tr.get('箱号');
        pkg.Application_QTY__c = Double.valueOf(tr.get('数量'));
        pkg.RTV_Order_Item__r = new RTV_Order_Item__c(UniqueKey__c= item.UniqueKey__c);
        
        // 检查相同的packingDetail（授权码+货品号+sku+季节码+箱号）
        String pkgKeyStr = item.UniqueKey__c + '{BoxCode:' + pkg.Box_Code__c + '}';
        if (this.allNewPackings.contains(pkgKeyStr)) {
            this.isError = true;
            this.resErrorCsv += '存在重复数据(授权码+货品号+尺寸(美码)+季节码)';
            return;
        }
        this.allNewPackings.add(pkgKeyStr);
        
        // 添加到待更新
        oneExe.insertPackings.put(pkgKeyStr, pkg);
        
        // 统计箱数
        this.totalOrderBoxess(shiptoCode, tr);
    }
    
    /** 统计order的箱数 */
    public void totalOrderBoxess(String shipToCode, RMS_CSV_Iterator.OneLineInfo tr) {
        BUBoxes buboxes = this.totalOrderBoxes.get(shiptoCode);
        if (buboxes == null) {
            buboxes = new BUBoxes();
        }
        
        String bu = RMS_CommonUtil.item_getBu2(tr.get('BU'));
        String boxCode = tr.get('箱号');
        
        if (bu.startsWithIgnoreCase('AP')) {
            buboxes.APBoxes.add(boxCode);
        } else if (bu.startsWithIgnoreCase('AC')) {
            buboxes.ACBoxes.add(boxCode);
        } else if (bu.startsWithIgnoreCase('F')) {
            buboxes.FWBoxes.add(boxCode);
        }
        
        this.totalOrderBoxes.put(shipToCode, buboxes);
    }
    
    /** 结束 */
    public void finish(Database.BatchableContext context){
        // 执行失败时，记录错误信息和返回的Csv文件
        if (this.isError == true) {
            RTV_Log__c log = new RTV_Log__c();
            log.Name = 'Upload PackingList';
            log.Batch_Job_Id__c = context.getJobId();
            insert log;
            
            Attachment attch = new Attachment();
            attch.Name = 'Error.csv';
            attch.ParentId = log.Id;
            attch.Body = Blob.valueOf(this.resErrorCsv);
            if (Test.isRunningTest() == false) {
                insert attch;
            }
            System.debug('存在错误, log.Id=' + log.Id);
        }
    }
    
    /**
     * 检索用对象: 一个 MaterialCode 对应的 program.SkuBudget 和 ProductList
     */
    class MaterialInfo {
        Map<String, RTV_RP_Sku_Budget__c> accGroupBudgets = new Map<String, RTV_RP_Sku_Budget__c>();
        Map<String, RTV_RP_Sku_Budget__c> soldToBudgets = new Map<String, RTV_RP_Sku_Budget__c>();
        Map<String, RTV_RP_Sku_Budget__c> shipToBudgets = new Map<String, RTV_RP_Sku_Budget__c>();
        RTV_RP_Sku_Budget__c globalBudget;
        
        List<RMS_Product__c> products = new List<RMS_Product__c>();
        
        /** 获取该MaterialCode的预算信息 */
        public RTV_RP_Sku_Budget__c getSkuBudget(RMS_Ship_To__c shipTo) {
            // 针对该shipTo的预算
            if (shipToBudgets.containsKey(shipTo.Name)) {
                return shipToBudgets.get(shipTo.Name);
            }
            // 针对该soldTo的预算
            if (soldToBudgets.containsKey(shipTo.Sold_To_Code__r.Name)) {
                return soldToBudgets.get(shipTo.Sold_To_Code__r.Name);
            }
            // 针对该AccountGroup的预算
            if (accGroupBudgets.containsKey(shipTo.Sold_To_Code__r.Account_Group__r.Name)) {
                return accGroupBudgets.get(shipTo.Sold_To_Code__r.Account_Group__r.Name);
            }
            // 全局预算
            return globalBudget;
        }
        
        /** 获取该MaterialCode的商品信息 */
        public RMS_Product__c getProduct(String seasonCodeCN, String bu) {
            // 获取Bu（只需要匹配csv中BU的前2个字符）
            String buSub = 
                bu.startsWithIgnoreCase('AP') ? 'AP':
                bu.startsWithIgnoreCase('AC') ? 'AC':
                bu.startsWithIgnoreCase('F') ? 'F': '';
            
            // 获取product
            for (RMS_Product__c pdt: this.products) {
                if (pdt.Season_Code_CN__c != null
                 && pdt.Season_Code_CN__c.equalsIgnoreCase(seasonCodeCN)
                 && pdt.BUCN__c.startsWith(buSub)) {
                    return pdt;
                }
            }
            return null;
        }
    }
    
    /** 统计用对象：用于统计各订单的箱数 */
    class BUBoxes{
        Set<String> APBoxes = new Set<String>();
        Set<String> ACBoxes = new Set<String>();
        Set<String> FWBoxes = new Set<String>();
    }
}