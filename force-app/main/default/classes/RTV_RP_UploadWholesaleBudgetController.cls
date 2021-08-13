public class RTV_RP_UploadWholesaleBudgetController {
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
    public Boolean isDeleteOtherSummaryBudget {get; set;}
    
    // csv必须列
    public String[] CSV_FIELDS = new String[]{'Account Group', 'QTY', 'MSRP', '$NET'};
    
    // 上传是否有错误信息
    private Boolean hasError;
    
    // accountGroups
    private Map<String, RMS_Account_Group__c> accountGroups;
    
    // 现存的summaryBudgets
    private Map<String, RTV_RP_Summary_Budget__c> existSummaryBudgets;
    
    // 新增或更新的summaryBudget
    private Map<String, RTV_RP_Summary_Budget__c> upsertSummaryBudgets;
    
    // 删除的summaryBudget
    private List<RTV_RP_Summary_Budget__c> deleteSummaryBugdets;

    /**
     * 构造方法
     */
    public RTV_RP_UploadWholesaleBudgetController() {
        this.isDeleteOtherSummaryBudget = true;
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
        this.accountGroups = new Map<String, RMS_Account_Group__c>();
        this.existSummaryBudgets = new Map<String, RTV_RP_Summary_Budget__c>();
        this.upsertSummaryBudgets = new Map<String, RTV_RP_Summary_Budget__c>();
        this.deleteSummaryBugdets = new List<RTV_RP_Summary_Budget__c>();
        
        // 检查input
        if (this.fileUploadBody == null) {
            RMS_CommonUtil.pageAddMessage(ApexPages.Severity.ERROR, 'CSV File is reuqired');
            return;
        }
        
        // 开始上传
        Savepoint savePot = Database.setSavepoint();
        try {
            // 检索accountgroup
            for (RMS_Account_Group__c accGrp: [
                SELECT Id, Name, OwnerId FROM RMS_Account_Group__c
            ]) {
                this.accountGroups.put(accGrp.Name.toUpperCase(), accGrp);
            }
            
            // 检索现存的summaryBudget
            for (RTV_RP_Summary_Budget__c sumBdg: [
                SELECT Id, Account_Group__r.Name
                FROM RTV_RP_Summary_Budget__c WHERE Return_Program__c = :this.programId
            ]) {
                this.existSummaryBudgets.put(sumBdg.Account_Group__r.Name.toUpperCase(), sumBdg);
            }
            
            // 创建csv迭代器
            RMS_CSV_Iterator csvIter = new RMS_CSV_Iterator(this.fileUploadBody, this.fileCharset);
            csvIter.skipTitleLine(this.CSV_FIELDS);
            
            // 遍历csv
            while (csvIter.next()) {
                RMS_CSV_Iterator.OneLineInfo tr = csvIter.getOneLineInfo();
                
                // 获取accountGroup
                String accGrpName = tr.get('Account Group');
                RMS_Account_Group__c accGrp = accountGroups.get(accGrpName.toUpperCase());
                if (accGrp == null) {
                    RMS_CommonUtil.pageAddMessage(ApexPages.Severity.WARNING, 'Account Group [' + accGrpName + '] does not exist.');
                    this.hasError = true;
                    continue;
                }
                
                // 重复数据检查
                if (this.upsertSummaryBudgets.containsKey(accGrpName.toUpperCase())) {
                    RMS_CommonUtil.pageAddMessage(ApexPages.Severity.WARNING, 'Please do not upload duplicate Account Group [' + accGrpName + '].');
                    this.hasError = true;
                    continue;
                }
                
                // 新增或更新
                RTV_RP_Summary_Budget__c sumBgd = new RTV_RP_Summary_Budget__c();
                RTV_RP_Summary_Budget__c extSumBgd = this.existSummaryBudgets.get(accGrpName.toUpperCase());
                if (extSumBgd == null) {
                    // 新增
                    sumBgd.Return_Program__c = this.programId;
                    sumBgd.Account_Group__c = accGrp.Id;
                    sumBgd.QTY__c = tr.getDecimal('QTY', 0);
                    sumBgd.MSRP__c = tr.getDecimal('MSRP', 0);
                    sumBgd.Tack_Back_Net__c = tr.getDecimal('$NET', 0);
                    sumBgd.OwnerId = accGrp.OwnerId;
                } else {
                    // 更新
                    sumBgd.Id = extSumBgd.Id;
                    sumBgd.QTY__c = tr.getDecimal('QTY', 0);
                    sumBgd.MSRP__c = tr.getDecimal('MSRP', 0);
                    sumBgd.Tack_Back_Net__c = tr.getDecimal('$NET', 0);
                    sumBgd.OwnerId = accGrp.OwnerId;
                }
                this.upsertSummaryBudgets.put(accGrp.Name.toUpperCase(), sumBgd);
            }
            
            // 执行更新
            if (!this.hasError && !this.upsertSummaryBudgets.isEmpty()) {
                // 新增或更新
                upsert this.upsertSummaryBudgets.values();
                // 删除其它s
                deleteOtherSummaryBudget();
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
     * 删除其它的summaryBudget
     */
    private void deleteOtherSummaryBudget() {
        // input参数
        if (!this.isDeleteOtherSummaryBudget) {
            return;
        }
            
        // 遍历现存的summaryBudget
        for (String accGrpName: this.existSummaryBudgets.KeySet()) {
            // 不在csv范围时
            if (!this.upsertSummaryBudgets.containsKey(accGrpName.toUpperCase())) {
                
                RTV_RP_Summary_Budget__c sumBdg = this.existSummaryBudgets.get(accGrpName.toUpperCase());
                this.deleteSummaryBugdets.add(sumBdg);
            }
        }
        // 删除
        if (!this.deleteSummaryBugdets.isEmpty()) {
            delete this.deleteSummaryBugdets;
        }
    }
}