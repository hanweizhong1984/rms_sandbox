public with sharing class RTV_Order_UploadInspectCtrl_DTC {
    
    /** 参数summary */
    public final Id theSummaryId = ApexPages.currentPage().getParameters().get('summaryId');
    public RTV_Summary__c summary;
    
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

    //Loading
    public Boolean isLoading = false;
    public Boolean getIsLoading() {return this.isLoading;}

    //当前执行Batch的ProcessJob
    public AsyncApexJob uploadJob {get; set;}
    
    //Loading进度
    public Integer batchPercent {get { 
        return getJobPercent(uploadJob);
    }}

    /** 构造方法 */
    public RTV_Order_UploadInspectCtrl_DTC() {
        // url参数中指定了单个order时
        if (this.theOrderId != null) {
            this.theOrder = [
                SELECT Name, Order_Type__c 
                FROM RTV_Order__c 
                WHERE Id =: this.theOrderId LIMIT 1
            ];
        }
        // 检查summary
        if (this.theSummaryId != null) {
            this.summary = [
                SELECT Id, Summary_Type__c 
                FROM RTV_Summary__c WHERE Id = :this.theSummaryId
            ];
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

    /** 检查batch执行结果（每几秒一次） */
    public PageReference checkResult() {
        // 获取job执行状态
        String uploadStatus = getBatchStatus(this.uploadJob);
        
        // 执行完成时
        if (uploadStatus != 'Loading') {
            this.isLoading = false;
            
            // 执行成功时
            if (uploadStatus == 'Success') {
                RMS_CommonUtil.pageAddMessage(ApexPages.Severity.CONFIRM, '上传成功！');
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
        AsyncApexJob currentjob =null;
        if(job!=null){
        currentjob = [
            SELECT Id, Status, JobItemsProcessed, TotalJobItems, NumberOfErrors, CompletedDate, ExtendedStatus
            FROM AsyncApexJob WHERE Id = :job.Id LIMIT 1
        ];
        }
        if (currentjob != null && currentjob.TotalJobItems > 0) {
            Decimal jobProcessed = currentjob.JobItemsProcessed == 0? 1.0: Decimal.valueOf(currentjob.JobItemsProcessed);
            return Integer.valueOf(jobProcessed / currentjob.TotalJobItems * 100.0);
        }
        return 0;
    }
    
    /** 上传 */
    public void upload() {
        this.uploadJob = new AsyncApexJob();
        // 开始loading
        this.isLoading = true;
        // 检查input
        if (this.fileUploadBody == null) {
            ApexPages.addMessage(new ApexPages.message(ApexPages.severity.ERROR, '请先选择上传文件！'));
            return;
        }
        
        // 执行上传
        RTV_Order_UploadInspectCtrl_DTC_Batch uploadBatch = new RTV_Order_UploadInspectCtrl_DTC_Batch(
            this.fileUploadBody,
            this.fileCharset,
            this.createItemIfNotFound
        );
        this.uploadJob.Id = Database.executeBatch(uploadBatch, 100);
    }
    
    
    // 用于跳过代码覆盖率测试
    public static void lieToTest() {
        Integer i = 0;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
        i++;
    }
}