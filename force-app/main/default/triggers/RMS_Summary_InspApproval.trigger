/**
 * summary审批时，更新order的状态
 */
trigger RMS_Summary_InspApproval on RTV_Summary__c (before update) {
    Set<Id> summIds_sumbit = new Set<Id>();
    Set<Id> summIds_finalApprove = new Set<Id>();
    Set<Id> summIds_finalReject = new Set<Id>();
    Set<Id> summIds_CsApprove = new Set<Id>();
    
    // 统计summary的审批动作
    for (RTV_Summary__c newSum: Trigger.new) {
        RTV_Summary__c oldSum = Trigger.oldMap.get(newSum.Id);
        // submit
        if (newSum.Insp_Submit_Time__c != oldSum.Insp_Submit_Time__c) {
            summIds_sumbit.add(newSum.Id);
        }
        // final approve
        if (newSum.Insp_Final_Approve_Time__c != oldSum.Insp_Final_Approve_Time__c) {
            summIds_finalApprove.add(newSum.Id);
        }
        // final reject
        if (newSum.Insp_Final_Reject_Time__c != oldSum.Insp_Final_Reject_Time__c) {
            summIds_finalReject.add(newSum.Id);
        }
        // cs approve
        if (newSum.Insp_CS_Approve_Time__c != oldSum.Insp_CS_Approve_Time__c) {
            summIds_CsApprove.add(newSum.Id);
        }
        // 只要修改了InspectQTY，就必须经过CS审批
        if (newSum.Inspect_QTY_A__c != oldSum.Inspect_QTY_A__c
            || newSum.Inspect_QTY_B__c != oldSum.Inspect_QTY_B__c
            || newSum.Inspect_QTY_C__c != oldSum.Inspect_QTY_C__c
            || newSum.Inspect_QTY_D__c != oldSum.Inspect_QTY_D__c
        ) {
            newSum.Insp_CS_Approve_Required__c = true;
        }
    }
    try {
        //----------------------------------
        // submit 时：将order变为'Insp Wait Approval'
        //----------------------------------
        if (!summIds_sumbit.isEmpty()) {
            
            List<RTV_Order__c> orders = [
                SELECT Id, Status__c FROM RTV_Order__c 
                WHERE Return_Summary__c IN :summIds_sumbit AND Status__c = 'Inspected'
            ];
            for (RTV_Order__c order: orders) {
                order.Status__c = 'Insp Wait Approval';
            }
            update orders;  
        }
        //----------------------------------
        // final approve 时：将order变为'Insp Confirmed'
        //----------------------------------
        if (!summIds_finalApprove.isEmpty()) {
            
            List<RTV_Order__c> orders = [
                SELECT Id FROM RTV_Order__c 
                WHERE Return_Summary__c IN :summIds_finalApprove AND Status__c = 'Insp Wait Approval'
            ];
            for (RTV_Order__c order: orders) {
                order.Actual_Date_Of_WSL_Confirmed__c = Date.today();
                order.Status__c = 'Insp Confirmed';
            }
            update orders;  
        }
        //----------------------------------
        // final reject 时：将order变为'Inspected'
        //----------------------------------
        if (!summIds_finalReject.isEmpty()) {
            
            List<RTV_Order__c> orders = [
                SELECT Id FROM RTV_Order__c 
                WHERE Return_Summary__c IN :summIds_finalReject AND Status__c = 'Insp Wait Approval'
            ];
            for (RTV_Order__c order: orders) {
                order.Status__c = 'Inspected';
            }
            update orders;  
        }
        //----------------------------------
        // final reject 时：更新 order 的CS审批时间
        //----------------------------------
        if (!summIds_CsApprove.isEmpty()) {
            
            List<RTV_Order__c> orders = [
                SELECT Id, Selling_Price_Error_Count__c, Return_Summary__c FROM RTV_Order__c 
                WHERE Return_Summary__c IN :summIds_CsApprove AND Status__c = 'Insp Wait Approval'
            ];
            for (RTV_Order__c order: orders) {
                order.Insp_Cs_Approve_Time__c = System.now();
            }
            update orders;
        }
    } catch (DmlException err) {
        Trigger.new[0].addError(err.getDmlMessage(0));
    }
}