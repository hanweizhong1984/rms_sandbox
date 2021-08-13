public class RTV_Order_ClearData {
    /** LoginUserInfo */
    public RMS_CommonUtil.LoginUserInfo loginUser = new RMS_CommonUtil.LoginUserInfo();
    public RMS_CommonUtil.LoginUserInfo getLoginUser() {return loginUser;}

    public final Id summaryId = ApexPages.currentPage().getParameters().get('summaryId');
    public final Id defSummaryId = ApexPages.currentPage().getParameters().get('defSummaryId');

    // orders
    public List<RTV_Order__c> objs {get; set;}

    /** 载入页面 */
    public void loadPage() {
        // 从RTVSummary页面进入时
        if (this.summaryId != null) {
            this.objs = [
                SELECT Id, Name, Status__c
                FROM RTV_Order__c WHERE Return_Summary__c = :summaryId AND Status__c = 'Ready'
            ];
        } 
        // 从RTVDEFSummary页面进入时
        else if (this.defSummaryId != null) {
            this.objs = [
                SELECT Id, Name, Status__c
                FROM RTV_Order__c WHERE RTV_DEF_Summary__c = :defSummaryId AND Status__c = 'Ready'
            ];
        }
    }

    /** 删除该Summary下的所有的没有被POST to LF的Order */
    public void clearData(){
        try {
            if(this.objs.size() < 1){
                ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.INFO, 'No data to clear'));
                return;
            }
            delete objs;
            ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.INFO, 'Cleared successfully'));
            
            loadPage();
        } catch (Exception err) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.ERROR, err.getMessage()));
        }
    }

    /** 返回上一页 */
    public PageReference cancel(){
        PageReference returnPage = new PageReference('/' + this.summaryId);
        returnPage.setRedirect(true);
        return returnPage;  
    }
}