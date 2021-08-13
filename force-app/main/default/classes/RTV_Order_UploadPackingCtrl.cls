public with sharing class RTV_Order_UploadPackingCtrl {
    /** url参数: summaryId */
    public String summaryId = ApexPages.currentPage().getParameters().get('id');
    
    /** 上传的文件正文 */
    public transient Blob fileUploadBody {get; set;}
    public String fileUploadName {get; set;}
    
    /** 文件编码 */
    public List<ApexPages.SelectOption> fileCharsetOpts {get{return RMS_CSV_Iterator.CHARSET_OPTIONS;}}
    public String fileCharset = fileCharsetOpts.get(0).getValue();
    public String getFileCharset() {return fileCharset;}
    public void setFileCharset(String value) {this.fileCharset=value;}
    
    /** 当前rtv_summary */
    public RTV_Summary__c summary {get; set;}
    
    /** admin用户的profile */
    private static String[] adminProfiles = new String[]{
        'System Administrator', '系统管理员', 'RMS Admin', 'RMS CS', 'RMS WSL HQ'
    };
    /** 可以从csv中指定shipto的用户profile */
    private static String[] csvShipToProfiles = new String[]{
        'System Administrator', '系统管理员', 'RMS Admin', 'RMS CS', 'RMS WSL HQ', 'RMS WSL Reg Branch', 'RMS WSL Sold To'
    };
    
    /** 现存数据：ShipTo白名单 */
    private Map<String, RTV_RP_Ship_To__c> shipToWhiteList;
    
    /** 页面选择的shipTo */
    public String shipToSelected {get; set;}
    public List<SelectOption> shipToSelectOptions {get; set;}

    /** 执行中的uploadBatch的job对象 */
    public AsyncApexJob uploadJob {get; set;}
    public Attachment resErrCsvFile {get; set;}
    public Boolean isLoading {get; set;}
    public Integer loadingPercent {get{ return getJobPercent(this.uploadJob); }}
    
    /**
     * 构造方法
     */
    public RTV_Order_UploadPackingCtrl() {
        this.querySummary();
        this.queryTargetShipToList();
    }
    
    /** 检索summary(页面初期化和每次上传后检索) */
    private void querySummary() {
        // 查询summary和program
        this.summary = [
            SELECT Id, Name, Account_Group__c, Account_Group__r.Name,
                Application_QTY__c, Application_Amount__c,
                Summary_Budget__r.QTY__c, Summary_Budget__r.Tack_Back_Net__c,
                RTV_Program__c, RTV_Program__r.Name , 
                RTV_Program__r.Discount__c,
                RTV_Program__r.TaxRate__c, RTV_Program__r.ExRate__c
            FROM RTV_Summary__c WHERE Id = :summaryId LIMIT 1
        ];
    }
    
    /** 检索shipto白名单(页面初期化时检索) */
    private void queryTargetShipToList() {
        this.shipToWhiteList = new Map<String, RTV_RP_Ship_To__c>();
        this.shipToSelectOptions = new List<SelectOption>();
        
        // 查询user.profile
        Id userId = UserInfo.getUserId();
        Profile userProfile = [
            SELECT Name FROM Profile WHERE Id = :UserInfo.getProfileId() LIMIT 1
        ];
        
        // 检索shipto白名单中的shipto.id
        Set<Id> shipToWLIds = new Set<Id>();
        for (RTV_RP_Ship_To__c sprp: [
            SELECT Ship_To__c, Order_Auth_Code__c,
                Ship_To__r.Name, 
                Ship_To__r.Code_Add__c,
                Ship_To__r.Contact_Pr__c,
                Ship_To__r.Contact_Tel1__c,
                Ship_To__r.Contact_Tel2__c,
                Ship_To__r.Dely_Addr__c,
                Ship_To__r.OwnerId,
                Ship_To__r.Owner.Profile.Name,
                Ship_To__r.Sold_To_Code__r.Name, 
                Ship_To__r.Sold_To_Code__r.Id,
                Ship_To__r.Sold_To_Code__r.OwnerId,
                Ship_To__r.Sold_To_Code__r.Owner.Profile.Name,
                Ship_To__r.Sold_To_Code__r.TT_APP_ACC__c, 
                Ship_To__r.Sold_To_Code__r.TT_FTW_EG__c, 
                Ship_To__r.Sold_To_Code__r.TT_FW_Seasonal__c,
                Ship_To__r.Sold_To_Code__r.Account_Group__r.Name,
                Ship_To__r.Sold_To_Code__r.Account_Group__r.OwnerId,
                Ship_To__r.Sold_To_Code__r.Account_Group__r.Owner.Profile.Name
            FROM RTV_RP_Ship_To__c
            WHERE Removed__c = false AND Summary__c = :summaryId
        ]) {
            this.shipToWhiteList.put(sprp.Ship_To__r.Name, sprp);
        }
                
        // 部分user附加选项：从csv中指定shipto
        if (csvShipToProfiles.contains(userProfile.Name)){
            this.shipToSelectOptions.add(new SelectOption('from_csv', '匹配csv中填写的ship-to'));
        }
        // 遍历shipto白名单检索结果
        for (RTV_RP_Ship_To__c sprp: this.shipToWhiteList.values()) {
            this.shipToSelectOptions.add(new SelectOption(sprp.Ship_To__r.Name, sprp.Ship_To__r.Name));
        }
    }
    
    /** 返回上一页 */
    public PageReference cancel(){
        PageReference returnPage = new PageReference('/' + this.summaryId);
        returnPage.setRedirect(true);
        return returnPage;
    }
    
    /** 上传 */
    public void upload() {
        // 检查文件
        if (this.fileUploadBody == null) {
            RMS_CommonUtil.pageAddMessage(ApexPages.severity.ERROR, '请选择上传文件！');
            return;
        }
        
        // 初期化
        this.isLoading = true;
        this.uploadJob = new AsyncApexJob();
        this.resErrCsvFile = null;
        
        // 创建batch
        RTV_Order_UploadPacking_Batch batch = new RTV_Order_UploadPacking_Batch();
        batch.summary = this.summary;
        batch.selectShipTo = this.shipToSelected;
        batch.shipToWhiteList = this.shipToWhiteList;
        batch.csvFileBody = this.fileUploadBody;
        batch.csvFileCharset = this.fileCharset;
        this.uploadJob.Id = Database.executeBatch(batch, 2000);
    }
    
    /** 获取uploadBatch的执行结构 */
    public void checkUploadResult() {
        // 检索batch的Job对象
        this.uploadJob = [
            SELECT Id, Status, JobItemsProcessed, TotalJobItems, NumberOfErrors, CompletedDate, ExtendedStatus
            FROM AsyncApexJob WHERE Id = :this.uploadJob.Id LIMIT 1
        ];
        // 执行结束时
        if (this.uploadJob.CompletedDate != null) {
            uploadFinish();
        }
    }
    
    /** 执行结束时的操作 */
    public void uploadFinish() {
        this.isLoading = false;
        
        // 检查异常
        if (!String.isBlank(this.uploadJob.ExtendedStatus)) {
            RMS_CommonUtil.pageAddMessage(ApexPages.Severity.ERROR, this.uploadJob.ExtendedStatus);
            return;
        } 
        // 检查自定义错误
        // 获取batch的自定义log
        List<RTV_Log__c> logs = [
            SELECT Errors__c, (SELECT Id FROM Attachments WHERE Name = 'Error.csv' LIMIT 1)
            FROM RTV_Log__c
            WHERE Batch_Job_ID__c = :this.uploadJob.Id LIMIT 1
        ];
        if (logs.size() > 0) {
            RTV_Log__c log = logs[0];
            
            // 错误信息
            if (!String.isBlank(log.Errors__c)) {
                RMS_CommonUtil.pageAddMessage(ApexPages.severity.ERROR, log.Errors__c);
                return;
            }
            // 错误的csv文件
            if (log.Attachments.size() > 0) {
                RMS_CommonUtil.pageAddMessage(ApexPages.severity.INFO, 'Packinglist上传失败！请参考返回的错误信息文件。');
                this.resErrCsvFile = log.Attachments[0];
                return;
            }
        }
        // 上传成功
        RMS_CommonUtil.pageAddMessage(ApexPages.severity.CONFIRM, '上传成功');
    }
    
    /** 静态方法：计算job执行进度 */
    private static Integer getJobPercent(AsyncApexJob job) {
        if (job != null && job.TotalJobItems > 0) {
            Decimal jobProcessed = job.JobItemsProcessed == 0? 1.0: Decimal.valueOf(job.JobItemsProcessed);
            return Integer.valueOf(jobProcessed / job.TotalJobItems * 100.0);
        }
        return 0;
    }
}