public class RTV_UploadRPWhiteListController {
    //PS: 不设置with sharing属性，即操作者可以不考虑权限处理任意记录
    
    // 参数：programId
    public final Id programId = ApexPages.currentPage().getParameters().get('id');
    
    // input.csv文件
    public transient Blob fileUploadBody{get;set;}
    public String fileUploadName{get;set;}
    
    // input.csv编码
    public List<ApexPages.SelectOption> fileCharsetOpts {get{return RMS_CSV_Iterator.CHARSET_OPTIONS;}}
    public String fileCharset = fileCharsetOpts.get(0).getValue();
    public String getFileCharset() {return fileCharset;}
    public void setFileCharset(String value) {this.fileCharset=value;}
    
    // input.是否删除其它SummaryBudget
    public Boolean isDeleteOtherShipToWL {get; set;}
    
    // csv必须列
    public final String[] CSV_FIELDS = new String[]{'Ship To'};
    
    // 上传是否有错误信息
    private transient Boolean hasError;
    
    // shipTos
    private transient Map<String, RMS_Ship_To__c> shipTos;
    
    // summaryBudgets
    private transient Map<String, RTV_RP_Summary_Budget__c> summaryBudgets;
    
    // 现存的shipto白名单
    private transient Map<String, RTV_RP_Ship_To__c> existShipToWL;
    
    // 新增或更新的shipto白名单
    private transient Map<String, RTV_RP_Ship_To__c> upsertShipToWL;
    
    // 删除的shipto白名单
    private transient List<RTV_RP_Ship_To__c> deleteShipToWL;
    
    /**
     * 构造方法
     */
    public RTV_UploadRPWhiteListController() {
        this.isDeleteOtherShipToWL = true;
    }
    /**
     * 关闭页面
     */
    public PageReference cancel(){
        PageReference returnPage = new PageReference('/' + this.programId);
        returnPage.setRedirect(true);
        return returnPage;  
    }
    /**
     * 上传文件
     */
    public void uploadFile() {
        this.hasError = false;
        this.shipTos = new Map<String, RMS_Ship_To__c>();
        this.summaryBudgets = new Map<String, RTV_RP_Summary_Budget__c>();
        this.existShipToWL = new Map<String, RTV_RP_Ship_To__c>();
        this.upsertShipToWL = new Map<String, RTV_RP_Ship_To__c>();
        this.deleteShipToWL = new List<RTV_RP_Ship_To__c>();
        
        // 检查input
        if (this.fileUploadBody == null) {
            RMS_CommonUtil.pageAddMessage(ApexPages.Severity.ERROR, 'CSV File is required');
            return;
        }
        
        // 开始上传
        Savepoint savePot = Database.setSavepoint();
        try {
            // 创建csv迭代器
            RMS_CSV_Iterator csvIter = new RMS_CSV_Iterator(this.fileUploadBody, this.fileCharset);
            csvIter.skipTitleLine(this.CSV_FIELDS);
            
            // 遍历csv,确定shipto范围
            List<RMS_CSV_Iterator.OneLineInfo> trs = new List<RMS_CSV_Iterator.OneLineInfo>();
            while (csvIter.next()) {
                RMS_CSV_Iterator.OneLineInfo tr = csvIter.getOneLineInfo();
                this.shipTos.put(tr.get('ship to'), null);
                trs.add(tr);
            }
            
            // 检索基础数据
            queryShipTos();
            querySummaryBudgets();
            queryShipToWhiteList();
            
            // 遍历csv,执行上传
            for (RMS_CSV_Iterator.OneLineInfo tr: trs) {
                
                // 获取shipto
                String shiptoCode = tr.get('Ship To');
                RMS_Ship_To__c shipto = this.shipTos.get(shiptoCode);
                if (shipto == null) {
                    RMS_CommonUtil.pageAddMessage(ApexPages.Severity.WARNING, 'Ship To [' + shiptoCode + '] does not exist.');
                    this.hasError = true;
                    continue;
                }
                if (shipTo.Sold_To_Code__r.TT_FTW_EG__c == null) {
                    RMS_CommonUtil.pageAddMessage(ApexPages.Severity.WARNING, 'Ship-to [' + shipTo.Name + ']: Sold-to\'s TT(FTW-EG) Is Empty');
                    this.hasError = true;
                    continue;
                }
                if (shipTo.Sold_To_Code__r.TT_FW_Seasonal__c == null) {
                    RMS_CommonUtil.pageAddMessage(ApexPages.Severity.WARNING, 'Ship-to [' + shipTo.Name + ']: Sold-to\'s TT(FTW-Seasonal) Is Empty');
                    this.hasError = true;
                    continue;
                }
                if (shipTo.Sold_To_Code__r.TT_APP_ACC__c == null) {
                    RMS_CommonUtil.pageAddMessage(ApexPages.Severity.WARNING, 'Ship-to [' + shipTo.Name + ']: Sold-to\'s TT(APP/ ACC) Is Empty');
                    this.hasError = true;
                    continue;
                }
                
                // 获取summarybudget
                String accGrpName = shipto.Sold_To_Code__r.Account_Group__r.Name;
                RTV_RP_Summary_Budget__c sumBgd = this.summaryBudgets.get(accGrpName.toUpperCase());
                if (sumBgd == null) {
                    RMS_CommonUtil.pageAddMessage(ApexPages.Severity.WARNING, 'Ship-to [' + shipTo.Name + ']: reuqired Summary Budget for Account Group ['+accGrpName+']');
                    this.hasError = true;
                    continue;
                }
                
                // 新增或更新
                RTV_RP_Ship_To__c upRpsp = new RTV_RP_Ship_To__c();
                RTV_RP_Ship_To__c extRpsp = this.existShipToWL.get(shipto.Name);
                if (extRpsp == null) {
                    // 新增
                    upRpsp.RTV_Program__c = this.programId;
                    upRPsp.Sold_To__c = shipto.Sold_To_Code__c;
                    upRPsp.Ship_To__c = shipto.Id;
                    upRpsp.Summary_Budget__c = sumBgd.Id;
                    upRpsp.OwnerId = shipto.OwnerId;
                } else {
                    // 更新
                    upRpsp.Id = extRpsp.Id;
                    upRpsp.OwnerId = shipto.OwnerId;
                }
                this.upsertShipToWL.put(shipto.Name, upRpsp);
            }
            
            // 执行更新
            if (!this.hasError && !this.upsertShipToWL.isEmpty()) {
                // 新增或更新
                upsert this.upsertShipToWL.values();
                // 删除其它s
                this.deleteOtherShipToWL();
                RMS_CommonUtil.pageAddMessage(ApexPages.Severity.CONFIRM, 'Upload Success');
            }
            else {
                RMS_CommonUtil.pageAddMessage(ApexPages.Severity.INFO, 'No Data upload');
            }
        } 
        catch (DmlException err) {
            for (Integer i=0; i<err.getNumDml(); i++) {
                RMS_CommonUtil.pageAddMessage(ApexPages.Severity.ERROR, err.getDmlMessage(i));
            }
            Database.rollback(savePot);
        }
        catch (Exception err) {
            RMS_CommonUtil.pageAddMessage(ApexPages.Severity.ERROR, err.getMessage());
            Database.rollback(savePot);
        }
    }
    /**
     * 检索shipto
     */
    private void queryShipTos() {
        for (RMS_Ship_To__c shipto: [
            SELECT Id,name, OwnerId,
                Sold_To_Code__c,
                Sold_To_Code__r.Name, 
                Sold_To_Code__r.TT_FTW_EG__c,
                Sold_To_Code__r.TT_FW_Seasonal__c,
                Sold_To_Code__r.TT_APP_ACC__c,
                Sold_To_Code__r.Account_Group__r.Name
            FROM RMS_Ship_To__c 
            WHERE name in :this.shipTos.KeySet()
        ]) {
            this.shipTos.put(shipto.Name, shipto);
            this.summaryBudgets.put(shipto.Sold_To_Code__r.Account_Group__r.Name.toUpperCase(), null);
        }
    }
    /**
     * 检索summaryBudgets
     */
    private void querySummaryBudgets() {
        for (RTV_RP_Summary_Budget__c sumBdg: [
            SELECT Id, Account_Group__r.Name
            FROM RTV_RP_Summary_Budget__c WHERE Return_Program__c = :this.programId
        ]) {
            this.summaryBudgets.put(sumBdg.Account_Group__r.Name.toUpperCase(), sumBdg);
        }
    }
    /**
     * 检索现存的shipto白名单
     */
    private void queryShipToWhiteList() {
        for (RTV_RP_Ship_To__c rpsp: [
            SELECT Id, Ship_To__r.Name
            FROM RTV_RP_Ship_To__c WHERE RTV_Program__c = :this.programId
        ]) {
            this.existShipToWL.put(rpsp.Ship_To__r.Name, rpsp);
        }
    }
    /**
     * 删除其它的summaryBudget
     */
    private void deleteOtherShipToWL() {
        // input参数
        if (!this.isDeleteOtherShipToWL) {
            return;
        }
            
        // 遍历现存的summaryBudget
        for (String shiptoCode: this.existShipToWL.KeySet()) {
            // 不在csv范围时
            if (!this.upsertShipToWL.containsKey(shiptoCode)) {
                
                RTV_RP_Ship_To__c rpsp = this.existShipToWL.get(shiptoCode);
                this.deleteShipToWL.add(rpsp);
            }
        }
        // 删除
        if (!this.deleteShipToWL.isEmpty()) {
            delete this.deleteShipToWL;
        }
    }
    
}