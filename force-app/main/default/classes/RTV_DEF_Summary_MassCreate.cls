public inherited sharing class RTV_DEF_Summary_MassCreate {
    
    // input 年月范围
    public Integer inputYear {get; set;}
    public Integer inputMonthFrom {get; set;}
    public Integer inputMonthTill {get; set;}
    
    /** 构造方法 */
    public RTV_DEF_Summary_MassCreate() {
        this.inputYear = System.today().year();
        this.inputMonthFrom = System.today().month();
        this.inputMonthTill = System.today().month();
    }
    
    /** LoginUserInfo */
    public RMS_CommonUtil.LoginUserInfo loginUser = new RMS_CommonUtil.LoginUserInfo();
    public RMS_CommonUtil.LoginUserInfo getLoginUser() {return loginUser;}
    
    /** 关闭页面 */
    public Pagereference cancel() {
        return new PageReference('/lightning/o/RTV_DEF_Summary__c/list');  
    }
    
    /** 批量创建DEFSummary */
    public void massCreate() {
        // 检查input
        if (inputYear == null || inputMonthFrom == null || inputMonthTill == null) {
            RMS_CommonUtil.pageAddMessage(ApexPages.Severity.ERROR, 'Please input correct Year and Month');
            return;
        }
        
        // 初期化
        Set<String> extDefSummaryNames = new Set<String>();
        List<RTV_DEF_Summary__c> newDefSummaries = new List<RTV_DEF_Summary__c>();
        
        // 检索现存的记录
        for (RTV_DEF_Summary__c defSum: [
            SELECT Id, Account_Group__c, Year__c, Month__c
            FROM RTV_DEF_Summary__c
            WHERE Year__c = :String.valueOf(this.inputYear)
            AND Month__c >= :this.inputMonthFrom
            AND Month__c <= :this.inputMonthTill
        ]) {
            extDefSummaryNames.add(defSum.Account_Group__c +'##'+ defSum.Year__c + '##' + defSum.Month__c);
        }
        
        // 遍历accountGroup
        for (RMS_Account_Group__c accGrp: [SELECT Id, Name FROM RMS_Account_Group__c]) {
            // 遍历年月范围
            for (Integer month = inputMonthFrom; month <= inputMonthTill; month++) {
                // 跳过已存在的defSummary
                if (extDefSummaryNames.contains(accGrp.Id +'##'+ String.valueOf(this.inputYear) + '##' + String.valueOf(month))) {
                    continue;
                }
                // 创建defsummary
                RTV_DEF_Summary__c defSum = new RTV_DEF_Summary__c();
                defSum.Year__c = String.valueOf(inputYear);
                defSum.Month__c = month;
                defSum.Account_Group__c = accGrp.Id;
                newDefSummaries.add(defSum);
            }
        }
        insert newDefSummaries;
        RMS_CommonUtil.pageAddMessage(ApexPages.Severity.CONFIRM, 'Created '+newDefSummaries.Size()+' DEF Summary');
    }
    
    /** 删除没有订单的defsummary */
    public void deleteNoOrderSummary() {
        // 检查input
        if (inputYear == null || inputMonthFrom == null || inputMonthTill == null) {
            RMS_CommonUtil.pageAddMessage(ApexPages.Severity.ERROR, 'Please input correct Year and Month');
            return;
        }
        
        List<RTV_DEF_Summary__c> delDefSummaries = new List<RTV_DEF_Summary__c>();
        
        // 检索现存的记录
        for (RTV_DEF_Summary__c defSum: [
            SELECT Id, Account_Group__c, Year__c, Month__c,
            (SELECT Id FROM RTV_Orders__r LIMIT 1)
            FROM RTV_DEF_Summary__c
            WHERE Year__c = :String.valueOf(this.inputYear)
            AND Month__c >= :this.inputMonthFrom
            AND Month__c <= :this.inputMonthTill
            AND Status__c = 'Pending'
        ]) {
            if (defSum.RTV_Orders__r.isEmpty()) {
                delDefSummaries.add(new RTV_DEF_Summary__c(Id=defSum.Id));
            }
        }
        if (!delDefSummaries.isEmpty()) {
            delete delDefSummaries;
            RMS_CommonUtil.pageAddMessage(ApexPages.Severity.CONFIRM, 'Delete '+delDefSummaries.Size()+' DEF Summary');
        } else {
            RMS_CommonUtil.pageAddMessage(ApexPages.Severity.INFO, 'No DEF Summary need delete');
        }
    }
}