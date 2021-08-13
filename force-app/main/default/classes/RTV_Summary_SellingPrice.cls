public with sharing class RTV_Summary_SellingPrice {
    public final Id summaryId = ApexPages.currentPage().getParameters().get('summaryId');
    
    public AsyncApexJob batchJob {get; set;}
    //页面显示order列表
    public List<RTV_Order__c> orderList{get;set;}
    //参数：税率
    public Decimal TaxRate{get;set;}
    
    // 载入中
    public Boolean isLoading {get; set;}
    // 载入中(进度%)
    public Integer loadingPercent {get { return getJobPercent(this.batchJob); }}

    //当前summaryy
    private RTV_Summary__c summary = new RTV_Summary__c();

    public RTV_Summary_SellingPrice(){
        this.orderList = [SELECT Name FROM RTV_Order__c WHERE Return_Summary__c = :this.summaryId AND Status__c = 'Insp Wait Approval'];
        this.summary = [SELECT Recall__c FROM RTV_Summary__c WHERE ID = :this.summaryId];
    }
    
    
    /** 关闭页面 */
    public PageReference cancel(){
        PageReference returnPage = new PageReference('/' + this.summaryId);
        returnPage.setRedirect(true);
        return returnPage;  
    }
    
    /** 开始执行 */
    public void startBatch() {
        this.isLoading = true;
        
        // 执行batch
        RTV_Summary_SellingPrice_Batch batch = new RTV_Summary_SellingPrice_Batch(this.summaryId,this.TaxRate);
        this.batchJob = new AsyncApexJob();
        this.batchJob.Id = Database.executeBatch(batch, 1); //SellingPricebatch一次执行一个order，这里参数只能设1

        update this.summary;
    }
    
    /** 检查执行结果 */
    public void checkResult() {
        // 检索batch
        this.batchJob = [
            SELECT Id, Status, JobItemsProcessed, TotalJobItems, NumberOfErrors, CompletedDate, ExtendedStatus
            FROM AsyncApexJob WHERE Id = :this.batchJob.Id LIMIT 1
        ];
        // 结束时
        if (this.batchJob.CompletedDate != null) {
            // 成功时
            if (String.isBlank(batchJob.ExtendedStatus)) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.CONFIRM, 'Get selling price success'));
            }
            // 错误信息
            if (!String.isBlank(batchJob.ExtendedStatus)) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.ERROR, batchJob.ExtendedStatus));
            }
            
            this.isLoading = false;
        }
    }
    
    /** 静态方法：计算job执行进度 */
    private static Integer getJobPercent(AsyncApexJob job) {
        if (job != null && job.TotalJobItems > 0) {
            return Integer.valueOf(job.JobItemsProcessed / job.TotalJobItems * 100.0);
        }
        return 0;
    }
}