/** 显示当前用户提交的审批记录 */
public with sharing class RMS_Home_MySubmitApproval {
    public List<ApprovalInfo> approvalInfos {get; set;}
    
    public RMS_Home_MySubmitApproval() {
        approvalInfos = new List<ApprovalInfo>();
        
        Set<Id> objIds = new Set<Id>();
        
        // 检索审批记录
        for (ProcessInstance process:[
            SELECT TargetObjectId, TargetObject.Name, TargetObject.Type, Status, 
                LastModifiedDate, LastActor.Name,
                (
                    SELECT Id, ActorId, Actor.Name, StepStatus
                    FROM Steps ORDER BY CreatedDate DESC
                ),
                (
                    SELECT Id, ActorId, Actor.Name
                    FROM Workitems ORDER BY CreatedDate DESC
                )
            FROM ProcessInstance
            WHERE Status IN ('Rejected', 'Pending')
            AND LastModifiedDate > :System.now().addDays(-30) //范围为30天以内
            // AND (TargetObject.Type LIKE 'RTV_%' OR TargetObject.Type LIKE 'RMS_%') 
            ORDER BY LastModifiedDate DESC
        ]) {
            // 同一个record只显示最新的审批记录
            if (!objIds.contains(process.TargetObjectId)) {
                objIds.add(process.TargetObjectId);
                
                // 检查submiter
                Id submiterId = null;
                for (ProcessInstanceStep step: process.Steps) {
                    if (step.StepStatus == 'Started') {
                        submiterId = step.ActorId;
                        break;
                    }
                }
                // submiter为当前用户时
                if (submiterId == UserInfo.getUserId()) {
                    // 获取审批信息
                    ApprovalInfo info = new ApprovalInfo();
                    info.process = process;
                    approvalInfos.add(info);
                }
            }
        }
    }
    
    class ApprovalInfo {
        public Id currentStepId {get {
            return this.process.Workitems.Size()>0? this.process.Workitems[0].Id: this.process.Steps[0].Id;
        }}
        public String currentApproverName {get {
            return this.process.Workitems.Size()>0? this.process.Workitems[0].Actor.Name: this.process.Steps[0].Actor.Name;
        }}
        public ProcessInstance process {get; set;}
    }
}