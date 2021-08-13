public class RTV_Summary_ClearData {
    /** LoginUserInfo */
    public RMS_CommonUtil.LoginUserInfo loginUser = new RMS_CommonUtil.LoginUserInfo();
    public RMS_CommonUtil.LoginUserInfo getLoginUser() {return loginUser;}

    public final Id programId = ApexPages.currentPage().getParameters().get('programId');

    // summaries
    public List<RTV_Summary__c> objs {get; set;}

    public RTV_Summary_ClearData() {
        this.objs = [
            SELECT Id, Name, Status__c
            FROM RTV_Summary__c WHERE RTV_Program__c = :programId AND Status__c = 'Pending'
        ];
    }

    /** 删除该Program下的所有的没有被Kick Off的Summary */
    public void clearData(){
        try {
            this.objs = [
                SELECT Id, Name, Status__c
                FROM RTV_Summary__c WHERE RTV_Program__c = :programId AND Status__c = 'Pending'
            ];

            if(this.objs.size() < 1){
                ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.INFO, 'No data to clear'));
                return;
            }

            Set<Id> summaryIds = new Set<Id>();
            for (RTV_Summary__c obj : this.objs) {
                summaryIds.add(obj.Id);
            }
            List<RTV_RP_Ship_To__c> rpshiptos = [SELECT Id FROM RTV_RP_Ship_To__c WHERE Summary__c IN:summaryIds];

            delete rpshiptos;
            delete objs;
            ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.INFO, 'Cleared successfully'));
        } catch (Exception err) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.ERROR, err.getMessage()));
        }
    }

    /** 返回上一页 */
    public PageReference cancel(){
        PageReference returnPage = new PageReference('/' + this.programId);
        returnPage.setRedirect(true);
        return returnPage;  
    }
}