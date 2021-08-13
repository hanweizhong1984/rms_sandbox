trigger RMS_Summary_StatusChange on RTV_Summary__c (before insert, before update, after update) {
    Set<Id> comSum = new Set<Id>();
    
    // ------------------------------------
    // summary.status变更前, 修改recordType
    // ------------------------------------
    if(Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)) {
        Map<String, RecordType> sumAllTypes;
        
        // 遍历新增或更新的summary
        for (RTV_Summary__c newSum: Trigger.new) {
            RTV_Summary__c oldSum = Trigger.isUpdate? trigger.oldMap.get(newSum.Id): null;
            
            //新增时，设置SalesChannel
            if (Trigger.isInsert) {
                newSum.Sales_Channel__c = 
                    newSum.DTC_Type__c == 'CFS'? 'CFS':
                    newSum.DTC_Type__c == 'Digital'? 'DIG':'WSL';
            }
            
            // 新增时，或更新Status、Owner时
            if (Trigger.isInsert 
            || (Trigger.isUpdate && newSum.Status__c != oldSum.Status__c)
            || (Trigger.isUpdate && newSum.IsOwnerWSL__c != oldSum.IsOwnerWSL__c)) {
                
                // 检索summary.allRecordTypes
                if (sumAllTypes == null) {
                    sumAllTypes = RMS_CommonUtil.getRecordTypes('RTV_Summary__c');
                }

                RecordType recType = null;
                
                // WSL TakeBack的情况
                if(newSum.Summary_Type__c != 'DTC Takeback') {
                    recType = newSum.Status__c == 'Remove' ? sumAllTypes.get('Remove'):
                        newSum.Status__c == 'Pending' && newSum.IsOwnerWSL__c == false? sumAllTypes.get('WSL Takeback Pending'):
                        newSum.Status__c == 'Pending' && newSum.IsOwnerWSL__c == true? sumAllTypes.get('WSL Takeback Pending To WSL'):
                        newSum.Status__c == 'Ready'  && newSum.IsOwnerWSL__c == false? sumAllTypes.get('WSL Takeback Ready'):
                        newSum.Status__c == 'Ready' && newSum.IsOwnerWSL__c == true? sumAllTypes.get('WSL Takeback Ready To WSL'):
                        newSum.Status__c == 'POST to LF' ? sumAllTypes.get('WSL Takeback Post LF'):
                        newSum.Status__c == 'Completed' ? sumAllTypes.get('WSL Takeback Post LF'):
                        null;
                }
                // DTC TakeBack的情况
                else {
                    recType = newSum.Status__c == 'Remove' ? sumAllTypes.get('DTC Takeback Remove'):
                        newSum.Status__c == 'Ready' ? sumAllTypes.get('DTC Takeback Ready'):
                        newSum.Status__c == 'POST to LF' ? sumAllTypes.get('DTC Takeback Post LF'):
                        newSum.Status__c == 'Completed' ? sumAllTypes.get('DTC Takeback Post LF'):
                        null;
                }
                if (recType != null) {
                    newSum.RecordTypeId = recType.Id;
                } else {
                    newSum.addError('Can not found record type for status ' + newSum.Status__c);
                }
            }
        }
    }
    
    try {
        // ------------------------------------
        // summary.status变为completed后, 更新关联program
        // ------------------------------------
        if(Trigger.isAfter && Trigger.isUpdate)
        {
            for (RTV_Summary__c newSum: Trigger.new) {
                RTV_Summary__c oldSum = Trigger.oldMap.get(newSum.Id);
                //状态：post to lf → completed
                if(newSum.Status__c == 'Completed' && oldSum.Status__c == 'POST to LF')
                {
                    comSum.add(newSum.RTV_Program__c);
                }
            }
        }
        //summary status: in progress → completed
        if(!comSum.isEmpty())
        {
            //更新program列表
            List<RTV_Program__c> updateProgram = new List<RTV_Program__c>();
            //当前program下所有summary的数量
            List<AggregateResult> allSummary = [SELECT COUNT(Id) Id ,RTV_Program__r.id program FROM Rtv_Summary__c WHERE RTV_Program__C IN :comSum GROUP BY RTV_Program__r.id];
            //当前parogram下状态为completed的数量
            List<AggregateResult> comSummary = [SELECT COUNT(Id) Id FROM Rtv_Summary__c WHERE RTV_Program__C IN :comSum AND Status__c ='Completed' GROUP BY RTV_Program__r.id];
            for(Integer i=0;i<allSummary.size();i++)
            {
                //判断数量相等
                if(allSummary.get(i).get('Id') == comSummary.get(i).get('Id'))
                {
                    //更新program状态
                    RTV_Program__c program = new RTV_Program__c();
                    program.id = (ID)allSummary.get(i).get('program');
                    program.Program_Status__c = 'Completed';
                    updateProgram.add(program);
                }
            }
            //更新记录
            update updateProgram;
        }

        // ------------------------------------
        // summary.status变更后, 更新其下order的status
        // ------------------------------------
        if(Trigger.isAfter && Trigger.isUpdate) {
            Map<Id, String> summaryIds = new Map<Id, String>();
            
            // 获取变更的summary.status
            for (RTV_Summary__c newSum: Trigger.new) {
                RTV_Summary__c oldSum = Trigger.oldMap.get(newSum.Id);
                
                // Summary状态变更时
                // （PS：Summary不会批量修改Order的状态）
                if (newSum.Status__c != oldSum.Status__c
                && newSum.Summary_Type__c != 'DTC Takeback') { 
                    summaryIds.put(newSum.Id, newSum.Status__c);
                }
            }
            
            // 检索该summary的orders
            if (!summaryIds.isEmpty()) {
                List<RTV_Order__c> orders = [
                    SELECT Id, Status__c, Return_Summary__c, Order_Type__c
                    FROM RTV_Order__c 
                    WHERE Return_Summary__c IN :summaryIds.keySet()
                    AND Application_QTY__c != 0
                ];
                
                // 更新order.status
                for (RTV_Order__c order: orders) {
                    String sumStatus = summaryIds.get(order.Return_Summary__c);
                    
                    // 修改order.status = summary.status
                    if (sumStatus != null && sumStatus != order.Status__c) {
                        // WSL TakeBack的情况
                        if(order.Order_Type__c != 'CFS DTC Takeback' && order.Order_Type__c != 'Digital DTC Takeback'){
                            if(order.Status__c != 'Ready' && sumStatus == 'POST to LF')
                            {
                                continue;
                            }
                            order.Status__c =
                                sumStatus == 'Remove' ? 'Remove':
                                sumStatus == 'Pending' ? 'Remove':
                                sumStatus == 'Ready' ? 'Ready':
                                sumStatus == 'POST to LF' ? 'POST to LF':
                                sumStatus == 'Completed' ? 'Completed':
                                null;
                        }
                        // （PS：Summary不会批量修改Order的状态）
                        // else {
                        //     order.Status__c =
                        //         sumStatus == 'Remove' ? 'Remove':
                        //         sumStatus == 'Ready' ? 'Ready':
                        //         sumStatus == 'Completed' ? 'Completed':
                        //         'Remove';
                        // }
                    }
                }
                update orders;  
            }
        }
    }  catch(DmlException err) {
        for(Integer i=0;i<err.getNumDml();i++) {
            Trigger.new[0].addError(err.getDmlMessage(i));
        }
    }
}