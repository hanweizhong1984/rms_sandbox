/**
 * 1.（仅WSL）统计Summary的KPI
 * 2.（仅WSL）Summary Complete时，更新program的实际金额
 */
trigger RMS_Summary_Date_Compute on RTV_Summary__c (before insert, before update,after update) {
    //读取全局变量中各个预计时间的偏移量
    ConverseRMS__c converseRMS = ConverseRMS__c.getOrgDefaults();
    
    // ------------------------------------------
    // （仅WSL）统计Summary的KPI
    // ------------------------------------------
    if (Trigger.isInsert) {
        for (RTV_Summary__c summary: Trigger.new) {
            // 非DTC时
            if (summary.DTC_Type__c != null) {
                continue;
            }
            summary.Date_Of_TB_Start__c = Date.today();
            summary.Next_Step__c = 'WSL Kickoff';
        }
    }
    if (Trigger.isUpdate && Trigger.isBefore) {
        for (RTV_Summary__c summary: Trigger.new) {
            RTV_Summary__c oldSummary = Trigger.oldMap.get(summary.id);
            // 非DTC时
            if (summary.DTC_Type__c != null) {
                continue;
            }
            
            //状态pending→ready Kick Off实际日期
            if(summary.Status__c == 'Ready' && oldSummary.Status__c == 'Pending')
            {
                summary.Actual_Date_Of_Kick_Off__c = Date.today();
                summary.Next_Step__c = 'WSL PKL';
                
                //预计时间计算
                summary.Expected_Date_Of_PTLF__c = summary.Actual_Date_Of_Kick_Off__c + Integer.valueOf(STRING.valueOf(converseRMS.Offset_Of_Kick_Off_To_PTLF__c)); 
                summary.Expected_Date_Of_Delivered__c = summary.Expected_Date_Of_PTLF__c + Integer.valueOf(STRING.valueOf(converseRMS.Offset_Of_PTLF_To_Delivered__c));
                summary.Expected_Date_Of_Inpected__c = summary.Expected_Date_Of_Delivered__c + Integer.valueOf(STRING.valueOf(converseRMS.Offset_Of_Delivered_To_Insp__c));
                summary.Expected_Date_Of_CS_Confirmed__c = summary.Expected_Date_Of_Inpected__c + Integer.valueOf(STRING.valueOf(converseRMS.Offset_Of_Insp_To_CS_Confirm__c));
                summary.Expected_Date_Of_WSL_Confirmed__c = summary.Expected_Date_Of_CS_Confirmed__c + Integer.valueOf(STRING.valueOf(converseRMS.Offset_Of_CS_Confirm_To_WSL_Confirm__c));
                summary.Expected_Date_Of_Inbound__c = summary.Expected_Date_Of_WSL_Confirmed__c + Integer.valueOf(STRING.valueOf(converseRMS.Offset_Of_WSL_Confirm_To_Inbound__c));
                summary.Expected_Date_Of_Completed__c = summary.Expected_Date_Of_Inbound__c + Integer.valueOf(STRING.valueOf(converseRMS.Offset_Of_Inbound_To_Completed__c));
            }
            
            //当LF修改质检完成预计日期，后面时间往后推移
            if(summary.Expected_Date_Of_Inpected__c != oldSummary.Expected_Date_Of_Inpected__c && summary.Expected_Date_Of_Inpected__c !=null) {
                

                summary.Expected_Date_Of_CS_Confirmed__c = summary.Expected_Date_Of_Inpected__c + Integer.valueOf(STRING.valueOf(converseRMS.Offset_Of_Insp_To_CS_Confirm__c));
                summary.Expected_Date_Of_WSL_Confirmed__c = summary.Expected_Date_Of_CS_Confirmed__c + Integer.valueOf(STRING.valueOf(converseRMS.Offset_Of_CS_Confirm_To_WSL_Confirm__c));
                summary.Expected_Date_Of_Inbound__c = summary.Expected_Date_Of_WSL_Confirmed__c + Integer.valueOf(STRING.valueOf(converseRMS.Offset_Of_WSL_Confirm_To_Inbound__c));
                summary.Expected_Date_Of_Completed__c = summary.Expected_Date_Of_Inbound__c + Integer.valueOf(STRING.valueOf(converseRMS.Offset_Of_Inbound_To_Completed__c));
            }
            
            //状态ready→postolf 授权备货实际日期
            if(summary.Status__c == 'POST to LF' && oldSummary.Status__c == 'Ready')
            {
                summary.Actual_Date_Of_PTLF__c = Date.today();
                summary.Next_Step__c = 'LF D';
            }
            // LF第一次完成物流的时间
            if(summary.Actual_Date_Of_Delivered__c != null && oldSummary.Actual_Date_Of_Delivered__c == null) {
                summary.Next_Step__c = 'LF Insp';
            }
            
            // LF提交审批时
            if (summary.Insp_Submit_Time__c != oldSummary.Insp_Submit_Time__c) {
                summary.Next_Step__c = summary.Insp_CS_Approve_Required__c? 'CS Confirm': 'WSL Confirm';
            }
            // LF初次提交审批的时间，作为质检实际完成日
            if(summary.Insp_Submit_Time__c != null && oldSummary.Insp_Submit_Time__c == null) {
                summary.Actual_Date_Of_Inspected__c = summary.Insp_Submit_Time__c.date();
            }
            
            // CS审批通过时
            if (summary.Insp_CS_Approve_Time__c != oldSummary.Insp_CS_Approve_Time__c) {
                summary.Next_Step__c = 'WSL Confirm';
            }
            // CS初次审批的时间，作为CS确认实际完成日
            if(summary.Insp_CS_Approve_Time__c != null && oldSummary.Insp_CS_Approve_Time__c == null)
            {
                summary.Actual_Date_Of_CS_Confirmed__c = summary.Insp_CS_Approve_Time__c.date();
            }
            
            // CS或WSL审批不通过时
            if (summary.Insp_Final_Reject_Time__c != oldSummary.Insp_Final_Reject_Time__c) {
                summary.Next_Step__c = 'LF Insp';
            }
            
            // WSL最终确认的时间，作为WSL确认实际完成日
            if(summary.Insp_Final_Approve_Time__c != null && oldSummary.Insp_Final_Approve_Time__c == null)
            {
                summary.Actual_Date_Of_WSL_Confirmed__c = summary.Insp_Final_Approve_Time__c.date();
                summary.Next_Step__c = 'LF Inbound (AB)';
            }
            
            //LF Inbound (ABD)完成时
            if(summary.LF_WH_Inbound_Date__c != null && oldSummary.LF_WH_Inbound_Date__c == null) {
                summary.Next_Step__c = 'CS Inbound';
            }

            //最终CS确认Inbound时间 Inbound完成实际日期
            if(summary.CS_Inbound_Date__c != null && oldSummary.CS_Inbound_Date__c == null)
            {
                summary.Actual_Date_Of_Inbound__c = summary.CS_Inbound_Date__c;
                summary.Next_Step__c = summary.Inspect_QTY_C__c > 0? 'LF Inbound (C)': null;
            }
            
            // 状态In Progress → Completed 授权备货实际日期
            if(summary.Status__c == 'Completed' && oldSummary.Status__c == 'POST to LF')
            {
                summary.Next_Step__c = null;

                //更新summary动态数量
                summary.Current_Status_QTY__C = summary.Inbound_QTY__c;
            }
        }
    }
    // ------------------------------------------
    // （包括DTC和WSL）Summary Complete时，更新program的实际金额
    // ------------------------------------------
    if(Trigger.isAfter) {
        //更新program
        Set<Id> programId = new Set<Id>();
        
        //遍历summary
        for(RTV_Summary__c summary :Trigger.new) {
            RTV_Summary__c oldSummary = Trigger.oldMap.get(summary.id);
            
            // 非DTC时
            if (summary.DTC_Type__c != null) {
                continue;
            }
            // 获取待更新program
            if(summary.Status__c == 'Completed' && oldSummary.Status__c == 'POST to LF') {
                programId.add(summary.RTV_Program__c);
            }
        }
        //当summary completed，统计该program下所有summary的inbound amount
        if(programId.size()>0) {
            List<AggregateResult> proDateList = [SELECT SUM(Inbound_Amount__c)  Inbound_Amount__c,
                                                        RTV_Program__c proId
                                                FROM RTV_Summary__c 
                                                WHERE RTV_Program__c IN :programId
                                                AND Status__c = 'Completed'
                                                Group By RTV_Program__c];
            //汇率                                    
            Decimal exRate = converseRMS.ExRate__c;
            
            List<RTV_Program__C> updatePro = new List<RTV_Program__C>();
            for(AggregateResult result:proDateList)   
            {
                RTV_Program__c program = new RTV_Program__c();
                program.id = (Id)result.get('proId');
                program.Actual_Amount__c = (Decimal)result.get('Inbound_Amount__c')/exRate;
                updatePro.add(program);
            }
            //更新program                             
            update updatePro;
        }
    }
}