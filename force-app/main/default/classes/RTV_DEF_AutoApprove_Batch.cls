/**
 * 自动完成WSL审批
 */
global class RTV_DEF_AutoApprove_Batch 
implements Database.Batchable<SObject>, Database.Stateful, Schedulable{
    
    /** 错误信息 */
    public Set<String> errorMessages = new Set<String>();
    
    /** 执行定时任务 */
    global void execute(SchedulableContext sc){
        RTV_DEF_AutoApprove_Batch batch = new RTV_DEF_AutoApprove_Batch();
        Database.executebatch(batch, 5000);
    }
    
    /** 开始 */
    public Database.QueryLocator start(Database.BatchableContext info){
        return Database.getQueryLocator([
            SELECT TargetObjectId, TargetObject.Name,
            (
                SELECT Id, ActorId, Actor.Name
                FROM StepsAndWorkitems
                WHERE IsPending = True
                AND StepStatus = 'Pending'
                AND ProcessNode.Name = 'WSL Approval'
                ORDER BY CreatedDate
                LIMIT 1
            )
            FROM ProcessInstance
            WHERE Status = 'Pending'
            AND TargetObject.Type = 'RTV_Order__c'
        ]);
    }
    
    /** 执行 */
    public void execute(Database.BatchableContext info, List<ProcessInstance> processlist) {
        List<Approval.ProcessWorkitemRequest> reqs = new List<Approval.ProcessWorkitemRequest>();
        
        // 遍历进行中的审批
        for (ProcessInstance process: processlist) {
            for (ProcessInstanceHistory step: process.StepsAndWorkitems) {
                reqs.add(approveAction(step));
            }
        }
        
        // 执行审批通过
        List<Approval.ProcessResult> proResults = Approval.process(reqs, true);
        
        // 检查结果
        for (Approval.ProcessResult res: proResults) {
            if (res.isSuccess() == false) {
                errorMessages.add(res.getErrors()[0].getMessage());
            }
        }
    }
    
    /** 创建审批请求 */
    public Approval.ProcessWorkitemRequest approveAction(ProcessInstanceHistory step) {
        Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest();
        req.setComments('审批请求已过期，由系统自动完成WSL审批。');
        req.setAction('Approve');
        req.setWorkitemId(step.Id);
        return req;
    }
    
    /** 结束 */
    public void finish(Database.BatchableContext ctx) {
        // 记录Batch中的错误
        if (this.errorMessages.size() != 0) {
            RTV_Log__c log = new RTV_Log__c();
            log.Batch_Job_Id__c = ctx.getJobId();
            log.Errors__c = String.join(new List<String>(this.errorMessages), '\r\n');
            insert log;
        }
    }
}