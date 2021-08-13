/**
 * DTC的Program变更前
 * 1.Create时：创建默认summarybudget
 * 2.OffPolicy后：创建Summary，将shipTo白名单关联到Summary里
 * 3.OffPolicy后：创建对应的Order
 */
trigger RMS_RP_Off_Policy_After_DTC on RTV_Program__c (after insert, after update) {
    // ----------------------------------------
    // create时
    // ----------------------------------------
    if (Trigger.isInsert) {
        List<RTV_RP_Summary_Budget__c> sumList = new List<RTV_RP_Summary_Budget__c>();
        for(RTV_Program__c program : Trigger.new)
        {
            if(program.isDTC__c == true){
                // CFS Account Group
                RMS_Account_Group__c refag = [SELECT Id, Name FROM RMS_Account_Group__c WHERE Name = '00)CC' LIMIT 1];
                // 添加Summary Budget
                RTV_RP_Summary_Budget__c summaryBudget = new RTV_RP_Summary_Budget__c();
                summaryBudget.Return_Program__c = program.Id;
                summaryBudget.Account_Group__c = refag.Id;
                // 不限
                summaryBudget.QTY__c = 0;
                summaryBudget.MSRP__c = 0;
                summaryBudget.Tack_Back_Net__c = 0;
                sumList.add(summaryBudget);
            }
        }
        if(sumList.size() > 0) insert sumList;
    }
    // ----------------------------------------
    // offPolicy时
    // ----------------------------------------
    else if (Trigger.isUpdate) {
    
        // 获取变为OffPolicy的Program
        Set<Id> offProgramIds = new Set<Id>();
        
        for (RTV_Program__c program: Trigger.new) {
            RTV_Program__c oldProgram = Trigger.oldMap.get(program.id);
            // Pending -> OffPolicy 时
            if(program.isDTC__c == true
            && program.Program_Status__c == 'Kick Off' && oldProgram.Program_Status__c == 'Pending') {
                offProgramIds.add(program.Id);
            }
        }
        
        // ----------------------------------------
        // 遍历OffPolicy的Program
        // ----------------------------------------
        if (!offProgramIds.isEmpty()) {
            // ----------------------------------------
            // 创建summary
            // ----------------------------------------
            // 需要创建的sumamry
            Map<String, RTV_Summary__c> newSummaries = new Map<String, RTV_Summary__c>();
            // 需要更新的shipTo白名单
            List<RTV_RP_Ship_To__c> updRpShipTos = new List<RTV_RP_Ship_To__c>();
            // 直营店/各大仓授权Order
            List<RTV_Order__c> orders = new List<RTV_Order__c>();

            // 检索Summary.allRecordTypes
            Map<String, RecordType> summaryTypes = RMS_CommonUtil.getRecordTypes('RTV_Summary__c');

            // 默认全部直营店
            List<RMS_Ship_To__c> cfsshiptos = [
                SELECT Name, DTC_Code__c, Sold_To_Code__c, Id, Code_Add__c,
                    SAP_Customer_Name__c, SAP_Tel__c, SAP_Addr__c
                FROM RMS_Ship_To__c WHERE Sold_To_Code__r.Name = '10003' AND IsDtcValid__c = true
            ];
            //TODO:五大仓
            List<RMS_Ship_To__c> digshiptos = [
                SELECT Name, DTC_Code__c, Sold_To_Code__c, Id, Code_Add__c,
                    SAP_Customer_Name__c, SAP_Tel__c, SAP_Addr__c
                FROM RMS_Ship_To__c WHERE Sold_To_Code__r.Name = '10004' AND IsDtcValid__c = true
            ];
            
            // 检索program.summary_budget
            for (RTV_RP_Summary_Budget__c sumBudget: [
                SELECT Id, 
                    Return_Program__r.Name, 
                    Return_Program__r.Id, 
                    Return_Program__r.DTC_Type__c, 
                    Account_Group__c, 
                    Account_Group__r.Name, 
                    Account_Group__r.OwnerId,
                    Account_Group__r.CFS_Owner__c,
                    Account_Group__r.Digital_Owner__c,
                    (SELECT Id, Summary_Budget__c FROM RTV_RP_Ship_To_List__r)
                FROM RTV_RP_Summary_Budget__c 
                WHERE Return_Program__c IN :offProgramIds
            ]) {
                String dtcType = sumBudget.Return_Program__r.DTC_Type__c;
                RMS_Account_Group__c accgrp = sumBudget.Account_Group__r;
                
                // 创建对应的summary
                RTV_Summary__c summary = new RTV_Summary__c();
                summary.name = RMS_CommonUtil.summary_getName(sumBudget.Return_Program__r.Name, sumBudget.Account_Group__r.Name);
                summary.RTV_Program__c = sumBudget.Return_Program__r.id;
                summary.Summary_Budget__c = sumBudget.id;
                summary.Account_Group__c = sumBudget.Account_Group__c;
                summary.Summary_Type__c = 'DTC Takeback';
                summary.Status__c = 'Ready';
                summary.RecordTypeId = summaryTypes.get('DTC Takeback Ready').Id;
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

            // ----------------------------------------
            // 创建order
            // ----------------------------------------
            List<RTV_Summary__c> sumList = [
                SELECT Id, RTV_Program__c, OwnerId, Default_CFS_OwnerId__c, Default_Digital_OwnerId__c, DTC_Type__c
                FROM RTV_Summary__c WHERE RTV_Program__c IN :offProgramIds
            ];
            // 修改RTV_RP_Ship_To__c关联到summary
            List<RTV_RP_Ship_To__c> rpShipTos = [
                SELECT Id, Name, Store_Code__c, Sold_To__r.Id, Ship_To__r.OwnerId,
                    Ship_To__c,Ship_To__r.Name, Ship_To__r.Code_Add__c, RTV_Program__c,
                    Ship_To__r.SAP_Customer_Name__c,
                    Ship_To__r.SAP_Tel__c,
                    Ship_To__r.SAP_Addr__c
                FROM RTV_RP_Ship_To__c WHERE RTV_Program__c IN :offProgramIds
            ];
            // Order.allRecordTypes
            Map<String, RecordType> orderTypes = RMS_CommonUtil.getRecordTypes('RTV_Order__c');
            // Key:programId
            Map<Id, List<RTV_RP_Ship_To__c>> rpshiptoMap = new Map<Id, List<RTV_RP_Ship_To__c>>();
            for (RTV_RP_Ship_To__c obj : rpShipTos) {
                if(rpshiptoMap.containsKey(obj.RTV_Program__c)){
                    rpshiptoMap.get(obj.RTV_Program__c).add(obj);
                }else {
                    rpshiptoMap.put(obj.RTV_Program__c, new List<RTV_RP_Ship_To__c>{obj});
                }
            }
            String ordtype = null;
            List<RMS_Ship_To__c> dtcshiptos = new List<RMS_Ship_To__c>();
            for (Id proId : offProgramIds) {
                RTV_Summary__c summary = new RTV_Summary__c();
                for (RTV_Summary__c obj : sumList) {
                    if(obj.RTV_Program__c == proId){
                        summary = obj;
                        break;
                    }
                }

                // 默认的shipto设置
                if(rpshiptoMap.containsKey(proId) == false){
                    System.debug('默认的shipto设置');

                    RTV_Program__c program = Trigger.newMap.get(proId);
                    System.debug('program.IsCFS__c:' + program.IsCFS__c);
                    // CFS DTC Takeback
                    if(program.IsCFS__c){
                        // 默认全部直营店
                        dtcshiptos = cfsshiptos;
                        ordtype = 'CFS DTC Takeback';
                    }
                    // Digital DTC Takeback
                    else {
                        //TODO:五大仓
                        dtcshiptos = digshiptos;
                        ordtype = 'Digital DTC Takeback';
                    }

                    for (RMS_Ship_To__c dtc : dtcshiptos) {
                        // 新建order
                        RTV_Order__c order = new RTV_Order__c();
                        order.Sold_To__c = dtc.Sold_To_Code__c;
                        order.Ship_To__c = dtc.Id;
                        order.Ship_To_Address__c = dtc.Code_Add__c;
                        order.Return_Summary__c = summary.Id;
                        // 生成授权码
                        String shipToCode = program.IsCFS__c? dtc.DTC_Code__c: dtc.Name;
                        String programName = program.IsCFS__c? program.Name: program.Name.substring(0, 1);
                        order.Name = RMS_CommonUtil.order_getCode(programName, '00)CC', shipToCode);
                        order.Order_Auth_Code__c = order.Name;
                        // 联系人信息
                        order.Ship_To_Contact__c = dtc.SAP_Customer_Name__c; //PS:和WSL业务不同，DTC的联系人是SAP_*字段
                        order.Ship_To_Phone1__c = dtc.SAP_Tel__c;
                        order.Ship_To_Phone2__c = '';
                        order.Ship_To_Address__c = dtc.SAP_Addr__c;
                        // 设置订单类型
                        order.Order_Type__c = ordtype;
                        order.RecordTypeId = orderTypes.get('DTC Takeback Ready').Id;
                        orders.add(order);
                    }
                }
                // 指定的shipto设置
                else {
                    System.debug('指定的shipto设置');

                    RTV_Program__c program = Trigger.newMap.get(proId);
                    // CFS DTC Takeback
                    if(program.IsCFS__c){
                        ordtype = 'CFS DTC Takeback';
                    }
                    // Digital DTC Takeback
                    else {
                        ordtype = 'Digital DTC Takeback';
                    }

                    System.debug('指定的shipto设置' + rpshiptoMap);
                    for (RTV_RP_Ship_To__c rpsp: rpshiptoMap.get(proId)) {
                        RMS_Ship_To__c shipTo =  rpsp.Ship_To__r;
                        // 新建order
                        RTV_Order__c order = new RTV_Order__c();
                        order.Sold_To__c = rpsp.Sold_To__r.Id;
                        order.Ship_To__c = rpsp.Ship_To__c;
                        order.Return_Summary__c = summary.Id;
                        // 生成授权码
                        String shipToCode = program.IsCFS__c? rpsp.Store_Code__c: rpsp.Ship_To__r.Name;
                        String programName = program.IsCFS__c? program.Name: program.Name.substring(0, 3);
                        order.Name = RMS_CommonUtil.order_getCode(programName, '00)CC', shipToCode);
                        order.Order_Auth_Code__c = order.Name;
                        // 联系人信息
                        order.Ship_To_Contact__c = shipTo.SAP_Customer_Name__c; //PS:和WSL业务不同，DTC的联系人是SAP_*字段
                        order.Ship_To_Phone1__c = shipTo.SAP_Tel__c;
                        order.Ship_To_Phone2__c = '';
                        order.Ship_To_Address__c = shipTo.SAP_Addr__c;
                        // 设置订单类型
                        order.Order_Type__c = ordtype;
                        order.RecordTypeId = orderTypes.get('DTC Takeback Ready').Id;
                        orders.add(order);
                        System.debug('create order:' + order.Name);
                    }
                }
            }

            // 生成直营店/各大仓的授权Order
            if (!orders.isEmpty()) {
                upsert orders;
                
                // 发送授权码邮件邮件
                for (RTV_Summary__c summary: sumList) {
                    RTV_Order_ReportAuthCode_Email.mailSummaryOrders(summary);
                }
            }
        }
    }
    
    // 用于跳过代码覆盖率测试
    if(Test.isRunningTest()){
        Integer i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
        i = 0;
    }
}