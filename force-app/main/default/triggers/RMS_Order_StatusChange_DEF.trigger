/**
 * order变为PostLF时: 更新DefSummary为InProcess
 */
trigger RMS_Order_StatusChange_DEF on RTV_Order__c (after update) {
    Set<Id> postlfSummaryIds = new Set<Id>();
    Set<Id> csApproveOrderIds = new Set<Id>();
    
    // 遍历order
    for (RTV_Order__c newOrd: Trigger.new) {
        if (newOrd.RTV_DEF_Summary__c != null) {
            RTV_Order__c oldOrd = Trigger.oldMap.get(newOrd.Id);
            
            // order更新为PostLF时
            if (oldOrd.Status__c == 'Ready' && newOrd.Status__c == 'POST to LF') {
                postlfSummaryIds.add(newOrd.RTV_DEF_Summary__c);
            }
            // order通过cs审批时
            if (oldOrd.Insp_CS_Approve_Time__c != newOrd.Insp_CS_Approve_Time__c) {
                csApproveOrderIds.add(newOrd.Id);
            }
        }
    }
    
    // ------------------------------
    // 任意order变为PostLf时，更新DefSummary为InProcess
    // ------------------------------
    if (postlfSummaryIds.size() > 0) {
        List<RTV_DEF_Summary__c> updDefSums = new List<RTV_DEF_Summary__c>();
        
        for (Id sumId: postlfSummaryIds) {
            RTV_DEF_Summary__c updDefSum = new RTV_DEF_Summary__c();
            updDefSum.Id = sumId;
            updDefSum.Status__c = 'In Process';
            updDefSums.add(updDefSum);
        }
        update updDefSums;
    }
    // ------------------------------
    // Order被CS审批时，发送邮件给WSL
    // ------------------------------
    if (csApproveOrderIds.size() > 0) {
        RTV_DEF_Approve_Email_Batch batch = new RTV_DEF_Approve_Email_Batch(csApproveOrderIds);
        Database.executebatch(batch, 5);
    }
}