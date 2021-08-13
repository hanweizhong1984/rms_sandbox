public with sharing class RTV_RP_UploadSKUBudgetController {

    //通过画面获取program id
    public String id = apexpages.currentPage().getParameters().get('id');
    
    //是否为金店
    public String isGoldStr = apexpages.currentPage().getParameters().get('isGold');
    public Boolean isGold { get{ return 'true'.equals(this.isGoldStr); } }
    
    //是否为DTC
    public Boolean IsDTC {get; set;}
    
    //input: 重新计算summaryBudget
    public Boolean isRecomputeSummaryBudget {get; set;}
    //input: 删除其它summaryBudget
    public Boolean isDeleteOtherSummaryBudget {get; set;}
    //input: 删除其它shipTo白名单
    public Boolean isDeleteOtherShipToWL {get; set;}
    
    //文件
    public transient Blob fileUploadBody{get;set;}
    public String fileUploadName{get;set;}

    //编码
    public List<ApexPages.SelectOption> fileCharsetOpts {get{return RMS_CSV_Iterator.CHARSET_OPTIONS;}}
    public String fileCharset = fileCharsetOpts.get(0).getValue();
    public String getFileCharset() {return fileCharset;}
    public void setFileCharset(String value) {this.fileCharset=value;}
    
    //Loading
    public Boolean isLoading = false;
    public Boolean getIsLoading() {return this.isLoading;}

    //当前执行Batch的ProcessJob
    public AsyncApexJob uploadJob {get; set;}
    public AsyncApexJob deleteJob {get; set;}
    
    //Loading进度
    public Integer batchPercent {get {
        return Integer.valueOf(getJobPercent(uploadJob) * 0.7) 
            + Integer.valueOf(getJobPercent(deleteJob) * 0.1);
    }}
    
    /** 构造方法 */
    public RTV_RP_UploadSKUBudgetController() {
        this.isRecomputeSummaryBudget = true;
        this.isDeleteOtherSummaryBudget = true;
        this.isDeleteOtherShipToWL = true;
        this.IsDTC = false;

        RTV_Program__c obj = [SELECT IsDTC__c FROM RTV_Program__c WHERE Id = :this.id];
        if(obj != null && obj.IsDTC__c){
            this.IsDTC = true;
            this.isDeleteOtherSummaryBudget = false;
        }

        system.debug('isDtc:' + this.IsDTC);
    }
    
    /** 返回program页面 */
    public PageReference cancel(){
        PageReference returnPage = new PageReference('/' + id);
        returnPage.setRedirect(true);
        return returnPage;  
    }
    
    /** 检查batch执行结果（每几秒一次） */
    public PageReference checkResult() {
        // 获取job执行状态
        String uploadStatus = getBatchStatus(this.uploadJob);
        String deleteStatus = getBatchStatus(this.deleteJob);
        
        // 执行完成时
        if (uploadStatus != 'Loading'
         && deleteStatus != 'Loading') {
            this.isLoading = false;
            
            // 执行成功时
            if (uploadStatus == 'Success'
            && deleteStatus == 'Success') {
                RMS_CommonUtil.pageAddMessage(ApexPages.Severity.CONFIRM, 'Upload Success');
            }
        }
        return null;
    }
    
    /** 检查Batch的执行状态 */
    private String getBatchStatus(AsyncApexJob job) {
        if (job == null || job.Id == null) {
            return 'Not Start';
        }
        
        // 获取Batch执行情况
        job = [
            SELECT Id, Status, JobItemsProcessed, TotalJobItems, NumberOfErrors, CompletedDate, ExtendedStatus
            FROM AsyncApexJob WHERE Id = :job.Id LIMIT 1
        ];
        if (job.CompletedDate == null) {
            return 'Loading';
        }
        
        // 执行结束
        // 检查异常信息
        Boolean hasError = false;
        if (!String.isBlank(job.ExtendedStatus)) {
            hasError = true;
            RMS_CommonUtil.pageAddMessage(ApexPages.Severity.ERROR, job.ExtendedStatus);
        }
        // 自定义错误信息
        for (RTV_Log__c log: [SELECT Id, Errors__c FROM RTV_Log__c WHERE Batch_Job_Id__c = :job.Id LIMIT 1]) {
            for (String msg: log.Errors__c.split('\r\n')) {
                hasError = true;
                RMS_CommonUtil.pageAddMessage(ApexPages.Severity.WARNING, msg);
            }
            delete log;
        }
        return hasError? 'Error': 'Success';
    }
    
    /** 计算job执行进度 */
    private Integer getJobPercent(AsyncApexJob job) {
        if (job != null && job.TotalJobItems > 0) {
            Decimal jobProcessed = job.JobItemsProcessed == 0? 1.0: Decimal.valueOf(job.JobItemsProcessed);
            return Integer.valueOf(jobProcessed / job.TotalJobItems * 100.0);
        }
        return 0;
    }
    
    /** 上传文件 */
    public void uploadFile() {
        this.uploadJob = new AsyncApexJob();
        this.deleteJob = new AsyncApexJob();
        
        // 文件内容是否为空
        if(fileUploadBody == null) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.WARNING,'No Upload Content'));
            return;
        }
        
        // 开始loading
        this.isLoading = true;
        
        // 删除旧的skuBudget
        this.deleteJob.Id = Database.executeBatch(new RMS_DeleteRecord_Batch(
            'SELECT Id FROM RTV_RP_SKU_Budget__c WHERE Return_Program__c = \'' + String.escapeSingleQuotes(this.id) +  '\''
        ), 9000);
        
        // 上传的batch
        RTV_RP_UploadSKUBudget_Batch uploadBatch = new RTV_RP_UploadSKUBudget_Batch(
            this.fileUploadBody,
            this.fileCharset,
            this.id,
            this.isGold
        );
        uploadBatch.isRecomputeSummaryBudget = this.isRecomputeSummaryBudget;
        uploadBatch.isDeleteOtherSummaryBudget = this.isDeleteOtherSummaryBudget;
        uploadBatch.isDeleteOtherShipToWL = this.isDeleteOtherShipToWL;
        this.uploadJob.Id = Database.executeBatch(uploadBatch, 1000);
    }
}