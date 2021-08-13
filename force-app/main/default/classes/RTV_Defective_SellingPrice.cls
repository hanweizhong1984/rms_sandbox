public inherited sharing class RTV_Defective_SellingPrice {
    
    // 参数: DEF Summary
    public final Id defSummaryId = ApexPages.currentPage().getParameters().get('defSummaryId');
    
    // 参数：Order范围仅为TB转DEF
    public final Boolean isFromTakeback = 'true'.equalsIgnoreCase(ApexPages.currentPage().getParameters().get('isFromTakeback'));
    
    // 页面显示: order列表
    public List<RTV_Order__c> orderList {get; set;}
    public Integer orderListCnt {get; set;}
    
    // 页面Input：税率
    public Decimal TaxRate{get;set;}
    
    // 批处理
    public AsyncApexJob batchJob {get; set;}
    // 载入中
    public Boolean isLoading {get; set;}
    // 载入中(进度%)
    public Integer loadingPercent {get { return getJobPercent(this.batchJob); }}

    /** 构造方法 */
    public RTV_Defective_SellingPrice() {
        if (isFromTakeback) {
            this.orderList = [
                SELECT Name FROM RTV_Order__c 
                WHERE RTV_DEF_Summary__c = :this.defSummaryId 
                AND Status__c = 'Insp Wait Approval'
                AND From_Takeback_Order__c != null
            ];
        } else {
            this.orderList = [
                SELECT Name FROM RTV_Order__c 
                WHERE RTV_DEF_Summary__c = :this.defSummaryId 
                AND Status__c = 'Insp Wait Approval'
                AND From_Takeback_Order__c = null
                AND Insp_CS_Approve_Time__c = null  //必须在CS审批前Mapping
            ];
        }
        this.orderListCnt = this.orderList.size();
        if (orderListCnt == 0) {
            RMS_CommonUtil.pageAddMessage(ApexPages.Severity.INFO, '没有CS审批中的订单.');
        }
    }
    
    /** 关闭页面 */
    public PageReference cancel(){
        PageReference returnPage = new PageReference('/' + this.defSummaryId);
        returnPage.setRedirect(true);
        return returnPage;  
    }
    
    /** 开始执行 */
    public void startBatch() {
        this.isLoading = true;
        
        // 执行batch
        RTV_Defective_SellingPrice_Batch batch = new RTV_Defective_SellingPrice_Batch(
            this.defsummaryId, this.TaxRate, this.isFromTakeback
        );
        this.batchJob = new AsyncApexJob();
        this.batchJob.Id = Database.executeBatch(batch, 1); //SellingPricebatch一次执行一个order，这里参数只能设1
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