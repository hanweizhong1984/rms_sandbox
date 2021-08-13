public class RTV_UploadStoreListController {
    //PS: 不设置with sharing属性，即操作者可以不考虑权限处理任意记录
    
    // 参数：programId
    public final Id programId = ApexPages.currentPage().getParameters().get('id');
    private RTV_Program__c program;
    
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
    public String[] CSV_CFS_FIELDS = new String[]{'Store'};
    public String[] CSV_DIG_FIELDS = new String[]{'Ship To'};
    
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
    public RTV_UploadStoreListController() {
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
        this.program = [SELECT IsCFS__c FROM RTV_Program__c WHERE Id = :this.programId];

        // 开始上传
        Savepoint savePot = Database.setSavepoint();
        try {
            // 创建csv迭代器
            RMS_CSV_Iterator csvIter = new RMS_CSV_Iterator(this.fileUploadBody, this.fileCharset);
            System.debug('skipTitleLine:' + this.CSV_CFS_FIELDS);

            if(this.program.IsCFS__c){
                csvIter.skipTitleLineIgnoreCase(this.CSV_CFS_FIELDS);
            }else {
                csvIter.skipTitleLineIgnoreCase(this.CSV_DIG_FIELDS);
            }
            
            // 遍历csv,确定shipto范围
            List<RMS_CSV_Iterator.OneLineInfo> trs = new List<RMS_CSV_Iterator.OneLineInfo>();
            while (csvIter.next()) {
                RMS_CSV_Iterator.OneLineInfo tr = csvIter.getOneLineInfo();
                if(this.program.IsCFS__c){
                    this.shipTos.put(tr.get('store'), null);
                }else {
                    this.shipTos.put(tr.get('ship to'), null);
                }
                trs.add(tr);
            }

            // 检索基础数据
            queryShipTos();
            querySummaryBudgets();
            queryShipToWhiteList();

            System.debug('shipTos:' + this.shipTos);
            
            // 遍历csv,执行上传
            for (RMS_CSV_Iterator.OneLineInfo tr: trs) {
                // 获取shipto
                String shiptoCode = '';
                if(this.program.IsCFS__c){
                    shiptoCode = tr.get('store');
                }else {
                    shiptoCode = tr.get('ship to');
                }
                RMS_Ship_To__c shipto = this.shipTos.get(shiptoCode);
                if (shipto == null) {
                    if(this.program.IsCFS__c){
                        RMS_CommonUtil.pageAddMessage(ApexPages.Severity.WARNING, 'Store [' + shiptoCode + '] does not exist.');
                    }else {
                        RMS_CommonUtil.pageAddMessage(ApexPages.Severity.WARNING, 'Ship To [' + shiptoCode + '] does not exist.');
                    }
                    this.hasError = true;
                    continue;
                }

                // 获取summarybudget
                String accGrpName = shipto.Sold_To_Code__r.Account_Group__r.Name;
                RTV_RP_Summary_Budget__c sumBgd = this.summaryBudgets.get(accGrpName.toUpperCase());
                if (sumBgd == null) {
                    if(this.program.IsCFS__c){
                        RMS_CommonUtil.pageAddMessage(ApexPages.Severity.WARNING, 'Store [' + shipTo.Name + ']: reuqired Summary Budget for Account Group ['+accGrpName+']');
                    }else {
                        RMS_CommonUtil.pageAddMessage(ApexPages.Severity.WARNING, 'Ship-to [' + shipTo.Name + ']: reuqired Summary Budget for Account Group ['+accGrpName+']');
                    }
                    this.hasError = true;
                    continue;
                }
                
                // 新增或更新
                RTV_RP_Ship_To__c upRpsp = new RTV_RP_Ship_To__c();
                RTV_RP_Ship_To__c extRpsp = this.existShipToWL.get(shipto.DTC_Code__c);
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
                this.upsertShipToWL.put(shipto.DTC_Code__c, upRpsp);
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
        String soldcode = '10003';
        if(!this.program.IsCFS__c){
            soldcode = '10004';
        }
        System.debug('queryShipTos start:' + soldcode);

        for (RMS_Ship_To__c shipto: [
            SELECT Id, Name, DTC_Code__c, 
                IsDtcValid__c,OwnerId,
                Sold_To_Code__c,
                Sold_To_Code__r.Name, 
                Sold_To_Code__r.TT_FTW_EG__c,
                Sold_To_Code__r.TT_FW_Seasonal__c,
                Sold_To_Code__r.TT_APP_ACC__c,
                Sold_To_Code__r.Account_Group__r.Name
            FROM RMS_Ship_To__c 
            WHERE DTC_Code__c in :this.shipTos.KeySet() AND IsDtcValid__c = true AND Sold_To_Code__r.Name =:soldcode
        ]) {
            System.debug('shipto:' + shipto.Sold_To_Code__r.Name);
            this.shipTos.put(shipto.DTC_Code__c, shipto);
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
            SELECT Id, Ship_To__r.DTC_Code__c
            FROM RTV_RP_Ship_To__c WHERE RTV_Program__c = :this.programId
        ]) {
            this.existShipToWL.put(rpsp.Ship_To__r.DTC_Code__c, rpsp);
        }
    }
    /**
     * 删除其它的shipto白名单
     */
    private void deleteOtherShipToWL() {
        // input参数
        if (!this.isDeleteOtherShipToWL) {
            return;
        }
            
        // 遍历现存的shipto白名单
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