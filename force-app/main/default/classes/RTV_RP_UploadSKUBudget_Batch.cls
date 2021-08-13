public class RTV_RP_UploadSKUBudget_Batch 
implements Database.Batchable<RMS_CSV_Iterator.OneLineInfo>, Database.Stateful {
    //PS: 不设置with sharing属性，即操作者可以不考虑权限处理任意记录
    
    /** 静态参数:CSV必须列标题 */ 
    public final static String[] CSV_FIELDS = new String[]{'sku', 'Account Group', 'Sold To', 'Ship To', 'QTY', 'MSRP', '$NET'};
    public final static String[] CFS_CSV_FIELDS = new String[]{'sku', 'Size', 'Account Group', 'Sold To', 'Store Id', 'QTY', 'MSRP', '$NET'};
    public final static String[] DIG_CSV_FIELDS = new String[]{'sku', 'Size', 'Account Group', 'Sold To', 'Ship To', 'QTY', 'MSRP', '$NET'};
    
    /** 参数:csv内容 */ 
    private final Blob fileUploadBody;
    private final String fileCharset;

    /** 参数:program.id */
    private final Id programId;
    private RTV_Program__c program;
    
    /** 参数:program是否为金店 */
    private final Boolean isGold;
    
    /** 参数: 重新计算summaryBudget */
    public Boolean isRecomputeSummaryBudget;
    
    /** 参数: 删除其它summaryBudget */
    public Boolean isDeleteOtherSummaryBudget;
    
    /** 参数: 删除其它shipTo白名单 */
    public Boolean isDeleteOtherShipToWL;
    
    /** csv范围内的所有summaryBudget */
    private Map<String, RTV_RP_Summary_Budget__c> allSummaryBudgets = new Map<String, RTV_RP_Summary_Budget__c>();
    private Set<Id> existSummaryIds = new Set<Id>();
    
    /** csv范围内的所有shipTo白名单 */
    private Map<String, RTV_RP_Ship_To__c> allShipToWhiteList = new Map<String, RTV_RP_Ship_To__c>();
    
    /** 维度 */
    private String dimension {get; set{
        if (this.dimension!= null && this.dimension != value) {
            throw new RMS_CommonUtil.RMSException(
                'The budget of ' +this.dimension+ ' and ' +value+ ' dimensions found at same time. ' +
                'Please upload only one dimension.'
            );
        }
        this.dimension = value;
    }}
    
    /** 单次Execute中的信息 */
    class OneExecuteInfo {
        // csv中的填写的soldto,shipto
        public Set<String> csvAccountGroupCodes = new Set<String>();
        public Set<String> csvSoldToCodes = new Set<String>();
        public Set<String> csvShipToCodes = new Set<String>();
        public Set<String> csvStoreCodes = new Set<String>();
        public Set<String> csvMaterialCodes = new Set<String>();
        
        // csv范围内的所有soldto,shipto
        public Map<String, RMS_Account_Group__c> accountGroupRange = new Map<String, RMS_Account_Group__c>();
        public Map<String, RMS_Sold_To__c> soldToRange = new Map<String, RMS_Sold_To__c>();
        public Map<String, RMS_Ship_To__c> shipToRange = new Map<String, RMS_Ship_To__c>();
        public Map<String, RMS_Ship_To__c> storeRange = new Map<String, RMS_Ship_To__c>();
        
        // 商品信息
        public Map<String, List<String>> products = new Map<String, List<String>>();
    }
    
    /** 错误信息 */
    public Set<String> errorMessages = new Set<String>();
    
    /** 构造方法 */
    public RTV_RP_UploadSKUBudget_Batch(Blob fileUploadBody, String fileCharset, Id programId, Boolean isGold) {
        this.fileUploadBody = fileUploadBody;
        this.fileCharset = fileCharset;
        this.isGold = isGold;
        this.programId = programId;
        
        this.program = [SELECT Id, IsDTC__c, IsCFS__c, Has_Global_Sku_Budget__c ,Rebuy__c FROM RTV_Program__c WHERE Id = :this.programId];
        this.program.Has_Global_Sku_Budget__c = false;
    }
    
    /** 开始 */
    public Iterable<RMS_CSV_Iterator.OneLineInfo> start(Database.BatchableContext context){
        // 返回csv迭代器
        RMS_CSV_Iterator csvIter = new RMS_CSV_Iterator(this.fileUploadBody, this.fileCharset);
        // DTC.CFS
        if(this.program.IsDTC__c && this.program.IsCFS__c){
            csvIter.skipTitleLine(CFS_CSV_FIELDS);
        } else if(this.program.IsDTC__c){
            csvIter.skipTitleLine(DIG_CSV_FIELDS);
        } else {
            csvIter.skipTitleLine(CSV_FIELDS);
        }
        return new RMS_CSV_Iterator.BatchIterable(csvIter); 
    }
    
    /** 执行部分csv行 */
    public void execute(Database.BatchableContext context, List<RMS_CSV_Iterator.OneLineInfo> trs){
        OneExecuteInfo info = new OneExecuteInfo();
        
        // 待新增的skuBudget
        List<RTV_RP_SKU_Budget__c> insertSkuBudgets = new List<RTV_RP_SKU_Budget__c>();
        
        // 遍历csv行，统计sku和shipto
        for (RMS_CSV_Iterator.OneLineInfo tr: trs) {
            info.csvMaterialCodes.add(tr.get('sku'));
            
            // shipto
            if (!this.program.IsCFS__c && !String.isBlank(tr.get('Ship To'))) {
                info.csvShipToCodes.add(tr.get('Ship To'));
                this.dimension = 'Ship To';
            }
            else if (this.program.IsCFS__c && !String.isBlank(tr.get('Store Id'))) {
                info.csvStoreCodes.add(tr.get('Store Id'));
                this.dimension = 'Store Id';
            }
            // soldto
            else if (!String.isBlank(tr.get('Sold To'))) {
                info.csvSoldToCodes.add(tr.get('Sold To'));
                this.dimension = 'Sold To';
            }
            // account group
            else if (!String.isBlank(tr.get('Account Group'))) {
                info.csvAccountGroupCodes.add(tr.get('account group'));
                this.dimension = 'Account Group';
            }
            else {
                this.dimension = 'Material Code';
            }
        }
        
        // 检索product
        this.queryProducts(info);
        
        // 检索范围内的所有shipTo
        this.queryShipToInRange(info);
        
        // 检索范围内的所有summaryBudget
        this.querySummarybudgetInRange(info);
        
        //检索范围内的所有ShipTo白名单
        this.queryShipToWhiteListInRange(info);
        
        // 遍历csv行，新增skubudget
        for (RMS_CSV_Iterator.OneLineInfo tr: trs) {
            // 商品不存在时
            List<String> pdt = info.products.get(tr.get('sku'));
            if (pdt == null) {
                this.errorMessages.add('Material Code [' + tr.get('sku') + '] does not exist.');
                continue;
            }
            // DTC和非金店，且商品在黑名单中时（只能上传非'Rebuy'的记录）
            if (!this.isGold && pdt.contains('Rebuy') && this.program.Rebuy__c) {
                this.errorMessages.add('Material Code [' + tr.get('sku') + '] is in black list.');
                continue;
            }
            
            // 新增skuBudget
            RTV_RP_SKU_Budget__c skuBudget = new RTV_RP_SKU_Budget__c();
            skuBudget.Return_Program__c = this.programId;
            skuBudget.SKU_Material_Code__c = tr.get('sku');
            skuBudget.Budget_QTY__c = tr.getDecimal('QTY', 0);
            skuBudget.Budget_MSRP__c = tr.getDecimal('MSRP', 0);
            skuBudget.Budget_NET__c = tr.getDecimal('$NET', 0);
            
            // DTC时上传size
            if (this.program.IsDTC__c != null) {
                skuBudget.Size__c = tr.get('Size');
            }
            
            // ---------------------------
            // 维度:Ship To
            // ---------------------------
            if (!this.program.IsCFS__c && !String.isBlank(tr.get('Ship To'))) {
                System.debug('info.shipToRange:' + info.shipToRange);
                System.debug('tr.get(Ship To):' + tr.get('Ship To'));
                // 获取shipto和白名单
                RMS_Ship_To__c shipTo = info.shipToRange.get(tr.get('Ship To'));
                if (shipTo == null) {
                    this.errorMessages.add('Ship To ['+tr.get('Ship To')+'] does not exist.');
                    continue;
                }
                RTV_RP_Ship_To__c shipToWL = this.allShipToWhiteList.get(shipTo.Name);
                skuBudget.RP_Ship_To__c = shipToWL.Id;
                skuBudget.OwnerId = shipTo.OwnerId;
                
                // 合计summaryBudget
                String sumBdgKey = shipTo.Sold_To_Code__r.Account_Group__r.Name.toUpperCase();
                RTV_RP_Summary_Budget__c sumBdg = this.allSummaryBudgets.get(sumBdgKey);
                sumBdg.Has_Sku_Budget__c = true;
                sumBdg.QTY__c += skuBudget.Budget_QTY__c;
                sumBdg.MSRP__c += skuBudget.Budget_MSRP__c;
                sumBdg.Tack_Back_NET__c += skuBudget.Budget_NET__c;
                skuBudget.Summary_Budget__c = sumBdg.Id;
            }
            // ---------------------------
            // 维度:Store
            // ---------------------------
            else if (this.program.IsCFS__c && !String.isBlank(tr.get('Store Id'))) {
                // 获取shipto和白名单
                RMS_Ship_To__c shipTo = info.storeRange.get(tr.get('Store Id'));
                if (shipTo == null) {
                    this.errorMessages.add('Store Id ['+tr.get('Store Id')+'] does not exist.');
                    continue;
                }
                RTV_RP_Ship_To__c shipToWL = this.allShipToWhiteList.get(shipTo.Name);
                skuBudget.RP_Ship_To__c = shipToWL.Id;
                skuBudget.OwnerId = shipTo.OwnerId;
                
                // 合计summaryBudget
                String sumBdgKey = shipTo.Sold_To_Code__r.Account_Group__r.Name.toUpperCase();
                RTV_RP_Summary_Budget__c sumBdg = this.allSummaryBudgets.get(sumBdgKey);
                sumBdg.Has_Sku_Budget__c = true;
                sumBdg.QTY__c += skuBudget.Budget_QTY__c;
                sumBdg.MSRP__c += skuBudget.Budget_MSRP__c;
                sumBdg.Tack_Back_NET__c += skuBudget.Budget_NET__c;
                skuBudget.Summary_Budget__c = sumBdg.Id;
            }
            // ---------------------------
            // 维度:Sold To
            // ---------------------------
            else if (!String.isBlank(tr.get('Sold To'))) {
                // 获取soldto
                RMS_Sold_To__c soldTo = info.soldToRange.get(tr.get('Sold To'));
                if (soldTo == null) {
                    this.errorMessages.add('Sold To ['+tr.get('Sold To')+'] does not exist.');
                    continue;
                }
                skuBudget.Sold_To__c = soldTo.Id;
                skuBudget.OwnerId = soldTo.OwnerId;
                
                // 合计summaryBudget
                String sumBdgKey = soldTo.Account_Group__r.Name.toUpperCase();
                RTV_RP_Summary_Budget__c sumBdg = this.allSummaryBudgets.get(sumBdgKey);
                sumBdg.Has_Sku_Budget__c = true;
                sumBdg.QTY__c += skuBudget.Budget_QTY__c;
                sumBdg.MSRP__c += skuBudget.Budget_MSRP__c;
                sumBdg.Tack_Back_NET__c += skuBudget.Budget_NET__c;
                skuBudget.Summary_Budget__c = sumBdg.Id;
            }
            // ---------------------------
            // 维度:Account Group
            // ---------------------------
            else if (!String.isBlank(tr.get('Account Group'))) {
                // 获取accountGroup
                RMS_Account_Group__c accGrp = info.accountGroupRange.get(tr.get('Account Group').toUpperCase());
                if (accGrp == null) {
                    this.errorMessages.add('Account Group ['+tr.get('Account Group')+'] does not exist.');
                    continue;
                }
                skuBudget.Account_Group__c = accGrp.Id;
                skuBudget.OwnerId = accGrp.OwnerId;
                
                // 合计summaryBudget
                String sumBdgKey = accGrp.Name.toUpperCase();
                RTV_RP_Summary_Budget__c sumBdg = this.allSummaryBudgets.get(sumBdgKey);
                sumBdg.Has_Sku_Budget__c = true;
                sumBdg.QTY__c += skuBudget.Budget_QTY__c;
                sumBdg.MSRP__c += skuBudget.Budget_MSRP__c;
                sumBdg.Tack_Back_NET__c += skuBudget.Budget_NET__c;
                skuBudget.Summary_Budget__c = sumBdg.Id;
            }
            // ---------------------------
            // 维度:Material Code
            // ---------------------------
            else {
                skuBudget.Is_Global_Sku_Budget__c = true;
                this.program.Has_Global_Sku_Budget__c = true;
            }
            
            // 添加skuBudget
            insertSkuBudgets.add(skuBudget);
        }
        insert insertSkuBudgets;
    }
    
    /** 检索product */
    private void queryProducts(OneExecuteInfo info) {
        for (RMS_Product__c pdt: [
            SELECT Id, Name, Material_Code__c, CFS_Rebuy__c FROM RMS_Product__c 
            WHERE Material_Code__c IN :info.csvMaterialCodes
        ]) {
            if(info.products.containsKey(pdt.Material_Code__c))
            {
                info.products.get(pdt.Material_Code__c).add(pdt.CFS_Rebuy__c);
            }
            else {
                List<String> pdtList = new List<String>();
                pdtList.add(pdt.CFS_Rebuy__c);
                info.products.put(pdt.Material_Code__c, pdtList);
            }
        }  
    }
    
    /** 检索csv中范围内的所有shipto */
    private void queryShipToInRange(OneExecuteInfo info) {
        // 检索shipTo
        for (RMS_Ship_To__c shipTo: [
            SELECT Id, Name, DTC_Code__c, 
                IsDtcValid__c, OwnerId,
                Sold_To_Code__r.Id,
                Sold_To_Code__r.Name,
                Sold_To_Code__r.OwnerId,
                Sold_To_Code__r.Account_Group__r.Id,
                Sold_To_Code__r.Account_Group__r.Name,
                Sold_To_Code__r.Account_Group__r.OwnerId
            FROM RMS_Ship_To__c
            WHERE Name IN :info.csvShipToCodes
            OR DTC_Code__c IN :info.csvStoreCodes
            OR Sold_To_Code__r.Name IN :info.csvSoldToCodes
            OR Sold_To_Code__r.Account_Group__r.Name IN :info.csvAccountGroupCodes
        ]) {
            RMS_Sold_To__c soldTo = shipTo.Sold_To_Code__r;
            RMS_Account_Group__c accGrp = shipTo.Sold_To_Code__r.Account_Group__r;
            
            // 获取ShipTo, SoldTo, AccountGroup
            if(this.program.IsDTC__c){
                if(shipTo.IsDtcValid__c && 
                    ((this.program.IsCFS__c && shipTo.Sold_To_Code__r.Name == '10003') || 
                    (!this.program.IsCFS__c && shipTo.Sold_To_Code__r.Name == '10004'))){
                    info.storeRange.put(shipTo.DTC_Code__c, shipTo);
                    info.shipToRange.put(shipTo.Name, shipTo);
                }
            }else {
                info.shipToRange.put(shipTo.Name, shipTo);
            }
            info.soldToRange.put(soldTo.Name, soldTo);
            info.accountGroupRange.put(accGrp.Name.toUpperCase(), accGrp);
        }
    }
    
    /** 创建summaryBudget */
    private void querySummarybudgetInRange(OneExecuteInfo info) {
        Map<String, RTV_RP_Summary_Budget__c> newSummaryBudgets = new Map<String, RTV_RP_Summary_Budget__c>();
        
        // 查询summaryBudget，补充到全局map里
        for (RTV_RP_Summary_Budget__c sumBgt: [
            SELECT Id, Account_Group__r.Name
            FROM RTV_RP_Summary_Budget__c
            WHERE Return_Program__c = :this.programId
            AND Account_Group__r.Name IN :info.accountGroupRange.KeySet()
            AND Account_Group__r.Name NOT IN :this.allSummaryBudgets.KeySet()
        ]) {
            sumBgt.Has_Sku_Budget__c = false;
            sumBgt.QTY__c = 0;
            sumBgt.MSRP__c = 0;
            sumBgt.Tack_Back_Net__c = 0;
            this.allSummaryBudgets.put(sumBgt.Account_Group__r.Name.toUpperCase(), sumBgt);
            this.existSummaryIds.add(sumBgt.Id);
        }
        
        // 遍历没有对应summaryBudget的accountGroup
        for (RMS_Account_Group__c accGrp: info.accountGroupRange.values()) {
            RTV_RP_Summary_Budget__c sumBdg = this.allSummaryBudgets.get(accGrp.Name.toUpperCase());
            if (sumBdg == null) {
                
                // 创建summaryBudget
                RTV_RP_Summary_Budget__c newSumBdg = new RTV_RP_Summary_Budget__c();
                newSumBdg.Return_Program__c = this.programId;
                newSumBdg.Account_Group__c = accGrp.Id;
                newSumBdg.Has_Sku_Budget__c = false;
                newSumBdg.QTY__c = 0;
                newSumBdg.MSRP__c = 0;
                newSumBdg.Tack_Back_Net__c = 0;
                newSumBdg.OwnerId = accGrp.OwnerId;
                newSummaryBudgets.put(accGrp.Name.toUpperCase(), newSumBdg);
            }
        }
        insert newSummaryBudgets.values();
        this.allSummaryBudgets.putAll(newSummaryBudgets);
    }
    
    /** 创建shipTo白名单 */
    private void queryShipToWhiteListInRange(OneExecuteInfo info) {
        Map<String, RTV_RP_Ship_To__c> newShipToWLs = new Map<String, RTV_RP_Ship_To__c>();
        
        // 查询ship-to白名单，补充到全局map里
        for (RTV_RP_Ship_To__c rpsp: [
            SELECT Id, Ship_To__r.Name
            FROM RTV_RP_Ship_To__c
            WHERE RTV_Program__c = :this.programId
            AND Ship_To__r.Name IN :info.shipToRange.KeySet()
            AND Ship_To__r.Name NOT IN :this.allShipToWhiteList.KeySet()
        ]) {
            this.allShipToWhiteList.put(rpsp.Ship_To__r.Name, rpsp);
        }
        
        // 遍历没有对应whitelist的shiptTo
        for (RMS_Ship_To__c shipTo: info.shipToRange.values()) {
            RTV_RP_Ship_To__c rpsp = this.allShipToWhiteList.get(shipTo.Name);
            if (rpsp == null) {
                
                // 获取该shipTo的accountGroup的summaryBudget
                RMS_Account_Group__c accGrp = shipTo.Sold_To_Code__r.Account_Group__r;
                RTV_RP_Summary_Budget__c sumBdg = this.allSummaryBudgets.get(accGrp.Name.toUpperCase());
                
                // 创建shipTo白名单
                RTV_RP_Ship_To__c newRpsp = new RTV_RP_Ship_To__c();
                newRpsp.RTV_Program__c = this.programId;
                newRpsp.Summary_Budget__c = sumBdg.Id;
                newRpsp.Sold_To__c = shipto.Sold_To_Code__c;
                newRpsp.Ship_To__c = shipto.Id;
                newRpsp.OwnerId = shipto.OwnerId;
                newShipToWLs.put(shipTo.Name, newRpsp);
            }
        }
        insert newShipToWLs.values();
        this.allShipToWhiteList.putAll(newShipToWLs);
    }
    
    /** 结束 */
    public void finish(Database.BatchableContext context){
        // 记录Batch执行信息
        if (this.errorMessages.size() != 0) {
            RTV_Log__c log = new RTV_Log__c();
            log.Batch_Job_Id__c = context.getJobId();
            log.Errors__c = String.join(new List<String>(this.errorMessages), '\r\n');
            insert log;
        }
        
        // 指定了accountGroup或soldto或shipto时
        if (this.dimension != 'Material Code') {
            
            // 更新summaryBudget合计
            List<RTV_RP_Summary_Budget__c> updSumBdgs = new List<RTV_RP_Summary_Budget__c>();
            for (RTV_RP_Summary_Budget__c sumBgd: this.allSummaryBudgets.values()) {
                // 更新现有的summaryBudget合计（页面选择Recalculation时）
                if (this.existSummaryIds.contains(sumBgd.Id)) {
                    if (this.isRecomputeSummaryBudget) {
                        RTV_RP_Summary_Budget__c updS = new RTV_RP_Summary_Budget__c();
                        updS.Id = sumBgd.Id;
                        updS.Has_Sku_Budget__c = sumBgd.Has_Sku_Budget__c;
                        updS.QTY__c = sumBgd.QTY__c;
                        updS.MSRP__c = sumBgd.MSRP__c;
                        updS.Tack_Back_Net__c = sumBgd.Tack_Back_Net__c;
                        updSumBdgs.add(updS);
                    }
                } 
                // 新增summaryBudget合计
                else {
                    RTV_RP_Summary_Budget__c updS = new RTV_RP_Summary_Budget__c();
                    updS.Id = sumBgd.Id;
                    updS.Has_Sku_Budget__c = sumBgd.Has_Sku_Budget__c;
                    updS.QTY__c = sumBgd.QTY__c;
                    updS.MSRP__c = sumBgd.MSRP__c;
                    updS.Tack_Back_Net__c = sumBgd.Tack_Back_Net__c;
                    updSumBdgs.add(updS);
                }
            }
            if (!updSumBdgs.isEmpty()) {
                update updSumBdgs;
            }
        
            // 删除其它的shipTo
            if (this.isDeleteOtherShipToWL) {
                delete [
                    SELECT Id FROM RTV_RP_Ship_To__c 
                    WHERE RTV_Program__c = :this.programId
                    AND Ship_To__r.Name NOT IN :this.allShipToWhiteList.KeySet()
                ];
            }
            
            // 删除其它的summaryBudget
            if (this.isDeleteOtherSummaryBudget) {
                delete [
                    SELECT Id FROM RTV_RP_Summary_Budget__c 
                    WHERE Return_Program__c = :this.programId
                    AND Account_Group__r.Name NOT IN :this.allSummaryBudgets.KeySet()
                ];
            }
        }
        
        // 更新program
        RTV_Program__c updProgram = new RTV_Program__c();
        updProgram.Id = this.program.Id;
        updProgram.Has_Global_Sku_Budget__c = this.program.Has_Global_Sku_Budget__c;
        update updProgram;
    }
}