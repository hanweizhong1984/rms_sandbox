/**
 * WSL的Program变更前
 * 1.OffPolicy后：创建Summary，将shipTo白名单关联到Summary里
 */
trigger RMS_RP_Off_Policy_After_WSL on RTV_Program__c (after update) {
    
    // 获取变为OffPolicy的Program
    Set<Id> offProgramIds = new Set<Id>();
    
    // ----------------------------------------
    // 遍历Status变更的(WSL的)Program
    // ----------------------------------------
    for (RTV_Program__c program: Trigger.new) {
        RTV_Program__c oldProgram = Trigger.oldMap.get(program.id);

        if(Trigger.isAfter)
        {
            // Pending -> OffPolicy 时
            if(program.isDTC__c == false
            && program.Program_Status__c == 'Off Policy' && oldProgram.Program_Status__c == 'Pending') {
                offProgramIds.add(program.Id);
            }
        }
  
    }
    
    // ----------------------------------------
    // 遍历OffPolicy的Program
    // ----------------------------------------
    if (!offProgramIds.isEmpty()) {
        // 需要创建的sumamry
        Map<String, RTV_Summary__c> newSummaries = new Map<String, RTV_Summary__c>();
        // 需要更新的shipTo白名单
        List<RTV_RP_Ship_To__c> updRpShipTos = new List<RTV_RP_Ship_To__c>();
        
        // 检索program.summary_budget
        for (RTV_RP_Summary_Budget__c sumBudget: [
            SELECT Id, 
                Return_Program__r.Name, 
                Return_Program__r.Finance_Code__c, 
                Return_Program__r.Id, 
                Account_Group__c, 
                Account_Group__r.Name, 
                Account_Group__r.OwnerId,
                (SELECT Id, Summary_Budget__c FROM RTV_RP_Ship_To_List__r)
            FROM RTV_RP_Summary_Budget__c 
            WHERE Return_Program__c IN :offProgramIds
        ]) {
            // 创建对应的summary
            RTV_Summary__c summary = new RTV_Summary__c();
            summary.name = RMS_CommonUtil.summary_getName(sumBudget.Return_Program__r.Finance_Code__c, sumBudget.Account_Group__r.Name);
            summary.RTV_Program__c = sumBudget.Return_Program__r.id;
            summary.Summary_Budget__c = sumBudget.id;
            summary.Account_Group__c = sumBudget.Account_Group__c;
            summary.OwnerId = sumBudget.Account_Group__r.OwnerId;
            newSummaries.put(summary.Summary_Budget__c, summary);
            
            // 待更新的ShipTo白名单
            for (RTV_RP_Ship_To__c rpsp: sumBudget.RTV_RP_Ship_To_List__r) {
                RTV_RP_Ship_To__c updRpsp = new RTV_RP_Ship_To__c();
                updRpsp.Id = rpsp.Id;
                updRpsp.Summary_Budget__c = rpsp.Summary_Budget__c;
                updRpShipTos.add(rpsp);
            }
        }
        // 创建summary
        if(!newSummaries.isEmpty()) {
            insert newSummaries.values();
        }
        // 更新shipTo白名单，将其添加到summary里
        if (!updRpShipTos.isEmpty()) {
            for (RTV_RP_Ship_To__c updRpsp: updRpShipTos) {
                updRpsp.Summary__c = newSummaries.get(updRpsp.Summary_Budget__c).Id;
            }
            update updRpShipTos;
        }
    }
}